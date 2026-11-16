//! EVE SSO access-token JWT signature verification against the
//! EVE JWKS (JSON Web Key Set). See `docs/jwt-verification-design.md`.
//!
//! Fail closed: any verification error rejects the token and
//! callers save nothing. Token values and key components are
//! never logged; every log line carries the `[AUTH]` tag.

use std::sync::Mutex;
use std::time::{Duration, Instant};

use jsonwebtoken::errors::ErrorKind;
use jsonwebtoken::{Algorithm, DecodingKey, Validation};
use serde::Deserialize;

use crate::auth::oauth::JwtClaims;
use crate::config::{now_unix, EveConfig};
use crate::error::AuthError;

/// Clock-skew allowance for `exp`/`nbf` checks, in seconds.
pub const JWT_LEEWAY_SECS: i64 = 60;
/// JWKS cache lifetime when the response carries no usable
/// `Cache-Control: max-age`.
pub const JWKS_DEFAULT_TTL_SECS: u64 = 300;
/// Hard cap on the JWKS cache lifetime, in seconds.
pub const JWKS_MAX_TTL_SECS: u64 = 3600;

/// The second audience EVE requires beside the client id.
const EVE_ONLINE_AUDIENCE: &str = "EVE Online";

/// The two issuer spellings CCP names, built from `OAUTH_HOST`.
fn accepted_issuers() -> [String; 2] {
    [
        EveConfig::OAUTH_HOST.to_string(),
        format!("https://{}", EveConfig::OAUTH_HOST),
    ]
}

/// One usable signing key from a JWKS document. Private: key
/// components never leave this module or reach a log line.
#[derive(Clone)]
pub(crate) struct Jwk {
    kid: String,
    alg: Algorithm,
    key: DecodingKey,
}

impl Jwk {
    #[cfg(test)]
    pub(crate) fn kid(&self) -> &str {
        &self.kid
    }
}

#[derive(Deserialize)]
struct RawJwks {
    #[serde(default)]
    keys: Vec<RawJwk>,
}

#[derive(Deserialize)]
struct RawJwk {
    #[serde(default)]
    kid: Option<String>,
    #[serde(default)]
    kty: Option<String>,
    #[serde(default)]
    crv: Option<String>,
    #[serde(default, rename = "use")]
    key_use: Option<String>,
    #[serde(default)]
    alg: Option<String>,
    #[serde(default)]
    n: Option<String>,
    #[serde(default)]
    e: Option<String>,
    #[serde(default)]
    x: Option<String>,
    #[serde(default)]
    y: Option<String>,
}

/// Parse a JWKS body and keep only usable keys (non-empty `kid`,
/// RSA or EC P-256 with components, `use`/`alg` gates, components
/// that actually decode into a verification key).
fn parse_usable_keys(body: &str) -> Result<Vec<Jwk>, AuthError> {
    let raw: RawJwks = serde_json::from_str(body).map_err(|_| {
        tracing::warn!("[AUTH] JWKS body unparseable");
        AuthError::JwksUnavailable
    })?;
    let total = raw.keys.len();
    let usable: Vec<Jwk> = raw.keys.into_iter().filter_map(usable_key).collect();
    tracing::debug!("[AUTH] JWKS parsed keys={} usable={}", total, usable.len());
    Ok(usable)
}

fn usable_key(raw: RawJwk) -> Option<Jwk> {
    let kid_label = raw.kid.clone().unwrap_or_default();
    let drop_key = |reason: &'static str| {
        tracing::debug!(
            "[AUTH] dropping unusable JWKS key kid={} reason={}",
            kid_label,
            reason
        );
        None
    };
    let kid = match raw.kid.as_deref() {
        Some(k) if !k.is_empty() => k.to_string(),
        _ => return drop_key("missing_kid"),
    };
    if let Some(key_use) = raw.key_use.as_deref() {
        if key_use != "sig" {
            return drop_key("bad_use");
        }
    }
    let (alg, alg_name, components) = match raw.kty.as_deref() {
        Some("RSA") => match (non_empty(raw.n.as_ref()), non_empty(raw.e.as_ref())) {
            (Some(n), Some(e)) => (Algorithm::RS256, "RS256", (n, e)),
            _ => return drop_key("missing_components"),
        },
        Some("EC") => {
            if raw.crv.as_deref() != Some("P-256") {
                return drop_key("unsupported_crv");
            }
            match (non_empty(raw.x.as_ref()), non_empty(raw.y.as_ref())) {
                (Some(x), Some(y)) => (Algorithm::ES256, "ES256", (x, y)),
                _ => return drop_key("missing_components"),
            }
        }
        _ => return drop_key("unsupported_kty"),
    };
    if let Some(key_alg) = raw.alg.as_deref() {
        if key_alg != alg_name {
            return drop_key("alg_mismatch");
        }
    }
    let key = match alg {
        Algorithm::RS256 => DecodingKey::from_rsa_components(components.0, components.1),
        _ => DecodingKey::from_ec_components(components.0, components.1),
    };
    match key {
        Ok(key) => Some(Jwk { kid, alg, key }),
        Err(_) => drop_key("bad_components"),
    }
}

fn non_empty(value: Option<&String>) -> Option<&str> {
    value.map(|s| s.as_str()).filter(|s| !s.is_empty())
}

/// Claims shape decoded only after the signature verifies.
/// `exp`, `iss`, and `aud` have no serde defaults: a missing
/// field is a decode error and the token is rejected.
#[derive(Deserialize)]
struct VerifiedClaims {
    #[serde(default)]
    sub: String,
    #[serde(default)]
    name: String,
    exp: i64,
    #[serde(default)]
    iat: i64,
    #[serde(default, deserialize_with = "crate::auth::oauth::deserialize_scp")]
    scp: Vec<String>,
    iss: String,
    #[serde(deserialize_with = "crate::auth::oauth::deserialize_aud")]
    aud: Vec<String>,
    #[serde(default)]
    nbf: Option<i64>,
    #[serde(default)]
    owner: Option<String>,
}

impl From<VerifiedClaims> for JwtClaims {
    fn from(verified: VerifiedClaims) -> Self {
        JwtClaims {
            sub: verified.sub,
            name: verified.name,
            exp: verified.exp,
            iat: verified.iat,
            scp: verified.scp,
            iss: Some(verified.iss),
            owner: verified.owner,
            aud: verified.aud,
            nbf: verified.nbf,
        }
    }
}

/// Map a `jsonwebtoken` error onto the closed `AuthError`
/// taxonomy. Every current kind is matched explicitly so a
/// signature error can never be relabelled a claims error (or
/// the reverse); the wildcard only covers future kinds.
fn map_jwt_error(kind: &ErrorKind) -> AuthError {
    match kind {
        ErrorKind::InvalidSignature => AuthError::InvalidSignature,
        ErrorKind::InvalidAlgorithm
        | ErrorKind::UnsupportedAlgorithm
        | ErrorKind::InvalidAlgorithmName
        | ErrorKind::MissingAlgorithm => AuthError::InvalidSignature,
        ErrorKind::ExpiredSignature => AuthError::InvalidClaims("expired"),
        ErrorKind::ImmatureSignature => AuthError::InvalidClaims("not_yet_valid"),
        ErrorKind::InvalidIssuer => AuthError::InvalidClaims("issuer"),
        ErrorKind::InvalidAudience => AuthError::InvalidClaims("audience"),
        ErrorKind::MissingRequiredClaim(claim) => match claim.as_str() {
            "exp" => AuthError::InvalidClaims("missing_exp"),
            "iss" => AuthError::InvalidClaims("issuer"),
            "aud" => AuthError::InvalidClaims("audience"),
            _ => AuthError::MalformedToken,
        },
        ErrorKind::InvalidClaimFormat(claim) => match claim.as_str() {
            "exp" => AuthError::InvalidClaims("missing_exp"),
            "nbf" => AuthError::InvalidClaims("not_yet_valid"),
            "iss" => AuthError::InvalidClaims("issuer"),
            "aud" => AuthError::InvalidClaims("audience"),
            _ => AuthError::MalformedToken,
        },
        ErrorKind::InvalidEcdsaKey
        | ErrorKind::InvalidEddsaKey
        | ErrorKind::InvalidRsaKey(_)
        | ErrorKind::InvalidKeyFormat => AuthError::JwksUnavailable,
        ErrorKind::RsaFailedSigning | ErrorKind::Signing(_) | ErrorKind::Provider(_) => {
            AuthError::InvalidSignature
        }
        ErrorKind::InvalidToken
        | ErrorKind::InvalidSubject
        | ErrorKind::Base64(_)
        | ErrorKind::Json(_)
        | ErrorKind::Utf8(_) => AuthError::MalformedToken,
        _ => AuthError::MalformedToken,
    }
}

/// Choose the closed error category for a signature-valid token
/// whose payload does not fit `VerifiedClaims`. The signature
/// already verified, so inspecting field presence here only
/// picks a rejection label; the token is rejected either way.
fn categorize_claims_shape(payload: &serde_json::Value) -> AuthError {
    if !payload.is_object() {
        return AuthError::MalformedToken;
    }
    if payload.get("exp").and_then(|v| v.as_i64()).is_none() {
        return AuthError::InvalidClaims("missing_exp");
    }
    if payload.get("iss").and_then(|v| v.as_str()).is_none() {
        return AuthError::InvalidClaims("issuer");
    }
    if payload.get("aud").is_none() {
        return AuthError::InvalidClaims("audience");
    }
    AuthError::MalformedToken
}

/// Pure verification core: no I/O, no clock, no cache. Steps
/// follow design Section 5 in order; no claims field is
/// returned until the signature and every claim check pass.
pub(crate) fn verify_with_keys(
    token: &str,
    keys: &[Jwk],
    client_id: &str,
    now_unix_secs: i64,
) -> Result<JwtClaims, AuthError> {
    let header = jsonwebtoken::decode_header(token).map_err(|_| {
        tracing::warn!("[AUTH] token header unparseable");
        AuthError::MalformedToken
    })?;
    let kid = match header.kid.as_deref() {
        Some(k) if !k.is_empty() => k,
        _ => {
            tracing::warn!("[AUTH] token header missing kid");
            return Err(AuthError::MalformedToken);
        }
    };
    let mut matches = keys.iter().filter(|k| k.kid == kid);
    let selected = match (matches.next(), matches.next()) {
        (Some(only), None) => only,
        (Some(_), Some(_)) => {
            tracing::warn!("[AUTH] duplicate signing key kid={}", kid);
            return Err(AuthError::UnknownSigningKey);
        }
        _ => {
            tracing::warn!("[AUTH] unknown signing key kid={}", kid);
            return Err(AuthError::UnknownSigningKey);
        }
    };
    // The algorithm comes from the selected key, never the
    // header; the header must merely agree with it.
    if header.alg != selected.alg {
        tracing::warn!(
            "[AUTH] token algorithm mismatch kid={} expected={:?} header={:?}",
            kid,
            selected.alg,
            header.alg
        );
        return Err(AuthError::InvalidSignature);
    }
    let issuers = accepted_issuers();
    let mut validation = Validation::new(selected.alg);
    validation.leeway = JWT_LEEWAY_SECS as u64;
    // The library reads the system clock for exp/nbf; this core
    // must evaluate time at the injected `now`, so the library
    // time checks are off and steps below apply the same rules.
    validation.validate_exp = false;
    validation.validate_nbf = false;
    validation.set_required_spec_claims(&["exp", "iss", "aud"]);
    validation.set_issuer(&issuers);
    validation.set_audience(&[client_id]);
    // Decode to a generic payload first so a claims-shape
    // failure can be labelled with the exact closed category;
    // the library has verified the signature before this point.
    let decoded = jsonwebtoken::decode::<serde_json::Value>(token, &selected.key, &validation)
        .map_err(|e| {
            let mapped = map_jwt_error(e.kind());
            tracing::warn!(
                "[AUTH] token verification failed kid={} error={}",
                kid,
                mapped
            );
            mapped
        })?;
    let verified: VerifiedClaims =
        serde_json::from_value(decoded.claims.clone()).map_err(|_| {
            let mapped = categorize_claims_shape(&decoded.claims);
            tracing::warn!(
                "[AUTH] token claims shape rejected kid={} error={}",
                kid,
                mapped
            );
            mapped
        })?;
    if !issuers.iter().any(|accepted| accepted == &verified.iss) {
        tracing::warn!("[AUTH] token issuer rejected kid={}", kid);
        return Err(AuthError::InvalidClaims("issuer"));
    }
    let has_client = verified.aud.iter().any(|aud| aud == client_id);
    let has_eve_online = verified.aud.iter().any(|aud| aud == EVE_ONLINE_AUDIENCE);
    if !has_client || !has_eve_online {
        tracing::warn!("[AUTH] token audience rejected kid={}", kid);
        return Err(AuthError::InvalidClaims("audience"));
    }
    if verified.exp <= 0 {
        tracing::warn!("[AUTH] token missing exp kid={}", kid);
        return Err(AuthError::InvalidClaims("missing_exp"));
    }
    if now_unix_secs >= verified.exp.saturating_add(JWT_LEEWAY_SECS) {
        tracing::warn!("[AUTH] token expired kid={}", kid);
        return Err(AuthError::InvalidClaims("expired"));
    }
    if let Some(nbf) = verified.nbf {
        if now_unix_secs.saturating_add(JWT_LEEWAY_SECS) < nbf {
            tracing::warn!("[AUTH] token not yet valid kid={}", kid);
            return Err(AuthError::InvalidClaims("not_yet_valid"));
        }
    }
    tracing::debug!("[AUTH] token verified kid={} alg={:?}", kid, selected.alg);
    Ok(JwtClaims::from(verified))
}

/// In-memory JWKS cache entry. Age is measured on the monotonic
/// `Instant` clock so a wall-clock step cannot extend key trust.
struct CachedJwks {
    keys: Vec<Jwk>,
    fetched_at: Instant,
    ttl: Duration,
}

/// Verifies freshly received EVE access tokens against the
/// SSO JWKS, failing closed on every error. One instance is
/// shared by the login, step-up, and refresh paths so they
/// see a single key cache.
pub struct JwtVerifier {
    http: reqwest::Client,
    jwks_url: String,
    client_id: String,
    cache: Mutex<Option<CachedJwks>>,
    ttl_override: Option<Duration>,
}

impl JwtVerifier {
    /// Production verifier: `OAUTH_JWKS_URL` + the public PKCE
    /// client id, over the shared default HTTP client shape.
    pub fn new() -> Result<Self, AuthError> {
        tracing::info!("[AUTH] creating JWT verifier");
        Ok(Self::with_endpoint(
            crate::auth::oauth::default_http()?,
            EveConfig::OAUTH_JWKS_URL.to_string(),
            EveConfig::CLIENT_ID.to_string(),
        ))
    }

    /// Injected-endpoint constructor (tests), mirroring
    /// `refresh_with` / `with_token_endpoint`.
    pub fn with_endpoint(http: reqwest::Client, jwks_url: String, client_id: String) -> Self {
        tracing::debug!("[AUTH] JWT verifier endpoint injected");
        Self {
            http,
            jwks_url,
            client_id,
            cache: Mutex::new(None),
            ttl_override: None,
        }
    }

    /// Test seam: force the cache TTL (e.g. `Duration::ZERO` to
    /// exercise the expired-cache path without sleeping).
    #[cfg(test)]
    pub(crate) fn with_ttl_override(mut self, ttl: Duration) -> Self {
        self.ttl_override = Some(ttl);
        self
    }

    fn lock_cache(&self) -> std::sync::MutexGuard<'_, Option<CachedJwks>> {
        self.cache
            .lock()
            .unwrap_or_else(|poisoned| poisoned.into_inner())
    }

    /// Fetch and parse the JWKS. Any failure is
    /// `JwksUnavailable`; the body is never logged.
    async fn fetch_jwks(&self) -> Result<CachedJwks, AuthError> {
        tracing::debug!("[AUTH] fetching JWKS");
        let response = self.http.get(&self.jwks_url).send().await.map_err(|_| {
            tracing::warn!("[AUTH] JWKS fetch failed (transport)");
            AuthError::JwksUnavailable
        })?;
        let status = response.status();
        if !status.is_success() {
            tracing::warn!("[AUTH] JWKS fetch failed status={}", status.as_u16());
            return Err(AuthError::JwksUnavailable);
        }
        let ttl = self.ttl_override.unwrap_or_else(|| {
            ttl_from_cache_control(
                response
                    .headers()
                    .get(reqwest::header::CACHE_CONTROL)
                    .and_then(|value| value.to_str().ok()),
            )
        });
        let body = response.text().await.map_err(|_| {
            tracing::warn!("[AUTH] JWKS body read failed");
            AuthError::JwksUnavailable
        })?;
        let keys = parse_usable_keys(&body)?;
        if keys.is_empty() {
            tracing::warn!("[AUTH] JWKS yielded zero usable keys");
            return Err(AuthError::JwksUnavailable);
        }
        tracing::debug!(
            "[AUTH] JWKS fetched usable={} ttl_secs={}",
            keys.len(),
            ttl.as_secs()
        );
        Ok(CachedJwks {
            keys,
            fetched_at: Instant::now(),
            ttl,
        })
    }

    /// Fetch, replace the cache (only a fetch with at least one
    /// usable key reaches this point), and return the keys.
    /// The lock is never held across the fetch await.
    async fn refresh_cache(&self) -> Result<Vec<Jwk>, AuthError> {
        let fetched = self.fetch_jwks().await?;
        let keys = fetched.keys.clone();
        *self.lock_cache() = Some(fetched);
        Ok(keys)
    }

    /// Verify a freshly received access token. `Ok` carries
    /// trusted claims; every failure rejects the token.
    pub async fn verify(&self, token: &str) -> Result<JwtClaims, AuthError> {
        tracing::debug!("[AUTH] verifying access token");
        let now = now_unix();
        let (cached_keys, fresh) = {
            let guard = self.lock_cache();
            match guard.as_ref() {
                Some(entry) => (
                    Some(entry.keys.clone()),
                    entry.fetched_at.elapsed() < entry.ttl,
                ),
                None => (None, false),
            }
        };
        let keys = match (cached_keys, fresh) {
            (Some(keys), true) => keys,
            _ => {
                // Cold or expired cache: refetch before use. A
                // failed refetch rejects; expired keys are
                // never used as a fallback.
                self.refresh_cache().await?
            }
        };
        match verify_with_keys(token, &keys, &self.client_id, now) {
            Err(AuthError::UnknownSigningKey) => {
                // Key rotation: exactly one forced refetch,
                // then one re-lookup whose result is returned
                // as-is. Never a second refetch, never a loop.
                tracing::debug!("[AUTH] unknown kid; forcing one JWKS refetch");
                let keys = self.refresh_cache().await?;
                verify_with_keys(token, &keys, &self.client_id, now)
            }
            other => other,
        }
    }
}

/// `Cache-Control: max-age`, capped; default when absent or
/// unparseable.
fn ttl_from_cache_control(header: Option<&str>) -> Duration {
    let max_age = header.and_then(|value| {
        value.split(',').find_map(|part| {
            part.trim()
                .strip_prefix("max-age=")
                .and_then(|secs| secs.trim().parse::<u64>().ok())
        })
    });
    match max_age {
        Some(secs) => Duration::from_secs(secs.min(JWKS_MAX_TTL_SECS)),
        None => Duration::from_secs(JWKS_DEFAULT_TTL_SECS),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::collections::VecDeque;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;

    use base64::engine::general_purpose::URL_SAFE_NO_PAD;
    use base64::Engine;
    use rsa::rand_core::{TryCryptoRng, TryRng};
    use rsa::sha2::{Digest as _, Sha256 as RsaSha256};
    use rsa::traits::PublicKeyParts;
    use rsa::{Pkcs1v15Sign, PrivateKey};
    use serde_json::{json, Value};
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    const CLIENT: &str = "test-client";
    /// Fixed "now" for the pure-core cases.
    const NOW: i64 = 1_700_000_000;

    /// TEST-ONLY RNG adapter: `rsa` 0.10 / `p256` 0.14 key
    /// generation wants rand_core 0.10 traits; the bytes come
    /// from the crate's existing rand 0.8 thread RNG.
    struct TestRng;

    impl TryRng for TestRng {
        type Error = std::convert::Infallible;

        fn try_next_u32(&mut self) -> Result<u32, Self::Error> {
            let mut bytes = [0u8; 4];
            self.try_fill_bytes(&mut bytes)?;
            Ok(u32::from_le_bytes(bytes))
        }

        fn try_next_u64(&mut self) -> Result<u64, Self::Error> {
            let mut bytes = [0u8; 8];
            self.try_fill_bytes(&mut bytes)?;
            Ok(u64::from_le_bytes(bytes))
        }

        fn try_fill_bytes(&mut self, dst: &mut [u8]) -> Result<(), Self::Error> {
            rand::RngCore::fill_bytes(&mut rand::thread_rng(), dst);
            Ok(())
        }
    }

    // `Rng`/`CryptoRng` arrive via rand_core blanket impls.
    impl TryCryptoRng for TestRng {}

    fn b64(bytes: &[u8]) -> String {
        URL_SAFE_NO_PAD.encode(bytes)
    }

    /// Minimal big-endian form for a JWK integer component.
    fn uint_b64(bytes: &[u8]) -> String {
        let mut start = 0;
        while start + 1 < bytes.len() && bytes[start] == 0 {
            start += 1;
        }
        b64(&bytes[start..])
    }

    /// TEST-ONLY: generate a 2048-bit RSA key in code (never
    /// committed material) plus its public JWKS entry.
    fn rsa_fixture(kid: &str) -> (PrivateKey, Value) {
        let private = PrivateKey::new(&mut TestRng, 2048).expect("rsa keygen");
        let jwk = json!({
            "kty": "RSA", "kid": kid, "use": "sig", "alg": "RS256",
            "n": uint_b64(&private.n().to_be_bytes()),
            "e": uint_b64(&private.e().to_be_bytes()),
        });
        (private, jwk)
    }

    /// TEST-ONLY: generate a P-256 key in code plus its JWKS entry.
    fn ec_fixture(kid: &str) -> (p256::ecdsa::SigningKey, Value) {
        use p256::elliptic_curve::Generate;
        let signing = p256::ecdsa::SigningKey::generate_from_rng(&mut TestRng);
        let point = signing.verifying_key().to_sec1_point(false);
        let bytes = point.as_bytes();
        assert_eq!(bytes.len(), 65, "uncompressed P-256 point");
        let jwk = json!({
            "kty": "EC", "crv": "P-256", "kid": kid, "use": "sig", "alg": "ES256",
            "x": b64(&bytes[1..33]),
            "y": b64(&bytes[33..65]),
        });
        (signing, jwk)
    }

    /// Manually sign a JWS signing input with RS256 (PKCS#1
    /// v1.5 + SHA-256), independent of the verifying library.
    fn sign_rs256(key: &PrivateKey, signing_input: &str) -> String {
        let digest = RsaSha256::digest(signing_input.as_bytes());
        let signature = key
            .sign(Pkcs1v15Sign::new::<RsaSha256>(), &digest)
            .expect("rs256 sign");
        b64(&signature)
    }

    fn sign_es256(key: &p256::ecdsa::SigningKey, signing_input: &str) -> String {
        use p256::ecdsa::signature::Signer;
        let signature: p256::ecdsa::Signature = key.sign(signing_input.as_bytes());
        b64(&signature.to_bytes())
    }

    /// HMAC-SHA256 by hand over the crate's `sha2`, for the
    /// HS256-forgery case only.
    fn sign_hs256(secret: &[u8], signing_input: &str) -> String {
        use sha2::{Digest as _, Sha256};
        let mut key = if secret.len() > 64 {
            Sha256::digest(secret).to_vec()
        } else {
            secret.to_vec()
        };
        key.resize(64, 0);
        let inner_pad: Vec<u8> = key.iter().map(|b| b ^ 0x36).collect();
        let outer_pad: Vec<u8> = key.iter().map(|b| b ^ 0x5c).collect();
        let inner = Sha256::new()
            .chain_update(inner_pad)
            .chain_update(signing_input.as_bytes())
            .finalize();
        let mac = Sha256::new()
            .chain_update(outer_pad)
            .chain_update(inner)
            .finalize();
        b64(&mac)
    }

    fn make_token(header: Value, payload: Value, sign: impl Fn(&str) -> String) -> String {
        let signing_input = format!(
            "{}.{}",
            b64(header.to_string().as_bytes()),
            b64(payload.to_string().as_bytes())
        );
        let signature = sign(&signing_input);
        format!("{signing_input}.{signature}")
    }

    fn header(alg: &str, kid: &str) -> Value {
        json!({"alg": alg, "kid": kid, "typ": "JWT"})
    }

    fn payload_at(now: i64) -> Value {
        json!({
            "sub": "CHARACTER:EVE:12345",
            "name": "Fixture Capsuleer",
            "exp": now + 1199,
            "iat": now,
            "scp": ["esi-skills.read_skills.v1"],
            "iss": "login.eveonline.com",
            "aud": [CLIENT, "EVE Online"],
            "owner": "fixture-owner",
        })
    }

    fn jwks_of(keys: &[Value]) -> String {
        json!({"keys": keys}).to_string()
    }

    fn keys_from(jwks: &str) -> Vec<Jwk> {
        parse_usable_keys(jwks).expect("jwks parses")
    }

    fn verify(token: &str, keys: &[Jwk]) -> Result<JwtClaims, AuthError> {
        verify_with_keys(token, keys, CLIENT, NOW)
    }

    // Case 1: valid RS256 (host issuer spelling; past `nbf` ok).
    #[test]
    fn valid_rs256() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let mut payload = payload_at(NOW);
        payload["nbf"] = json!(NOW - 10);
        let token = make_token(header("RS256", "rsa-1"), payload, |input| {
            sign_rs256(&private, input)
        });
        let claims = verify(&token, &keys).expect("valid rs256 verifies");
        assert_eq!(claims.character_id(), Some(12345));
        assert_eq!(claims.scp, vec!["esi-skills.read_skills.v1".to_string()]);
        assert_eq!(claims.exp, NOW + 1199);
        assert_eq!(claims.name, "Fixture Capsuleer");
        assert_eq!(
            claims.aud,
            vec![CLIENT.to_string(), "EVE Online".to_string()]
        );
        assert_eq!(claims.nbf, Some(NOW - 10));
    }

    // Case 2: valid ES256 (URI issuer spelling).
    #[test]
    fn valid_es256() {
        let (signing, jwk) = ec_fixture("ec-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let mut payload = payload_at(NOW);
        payload["iss"] = json!("https://login.eveonline.com");
        let token = make_token(header("ES256", "ec-1"), payload, |input| {
            sign_es256(&signing, input)
        });
        let claims = verify(&token, &keys).expect("valid es256 verifies");
        assert_eq!(claims.character_id(), Some(12345));
        assert_eq!(claims.iss.as_deref(), Some("https://login.eveonline.com"));
        assert_eq!(claims.exp, NOW + 1199);
    }

    // Case 3: expired, with both sides of the 60 s leeway.
    #[test]
    fn expired_and_leeway_boundary() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let token_with_exp = |exp: i64| {
            let mut payload = payload_at(NOW);
            payload["exp"] = json!(exp);
            make_token(header("RS256", "rsa-1"), payload, |input| {
                sign_rs256(&private, input)
            })
        };
        assert!(matches!(
            verify(&token_with_exp(NOW - 3600), &keys),
            Err(AuthError::InvalidClaims("expired"))
        ));
        // Boundary: now < exp + 60 must hold. exp = now - 59
        // passes; exp = now - 60 fails.
        assert!(verify(&token_with_exp(NOW - 59), &keys).is_ok());
        assert!(matches!(
            verify(&token_with_exp(NOW - 60), &keys),
            Err(AuthError::InvalidClaims("expired"))
        ));
    }

    // Case 4: wrong issuer spellings and missing issuer.
    #[test]
    fn wrong_issuer() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let token_with = |payload: Value| {
            make_token(header("RS256", "rsa-1"), payload, |input| {
                sign_rs256(&private, input)
            })
        };
        for bad_iss in ["evil.example.com", "http://login.eveonline.com"] {
            let mut payload = payload_at(NOW);
            payload["iss"] = json!(bad_iss);
            assert!(matches!(
                verify(&token_with(payload), &keys),
                Err(AuthError::InvalidClaims("issuer"))
            ));
        }
        let mut payload = payload_at(NOW);
        payload.as_object_mut().expect("object").remove("iss");
        assert!(matches!(
            verify(&token_with(payload), &keys),
            Err(AuthError::InvalidClaims("issuer"))
        ));
    }

    // Case 5: audience must contain BOTH the client id and
    // "EVE Online"; `azp` is not a substitute.
    #[test]
    fn wrong_audience() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let token_with = |payload: Value| {
            make_token(header("RS256", "rsa-1"), payload, |input| {
                sign_rs256(&private, input)
            })
        };
        let mut no_client = payload_at(NOW);
        no_client["aud"] = json!(["EVE Online"]);
        let mut no_eve_online = payload_at(NOW);
        no_eve_online["aud"] = json!([CLIENT]);
        let mut string_client_only = payload_at(NOW);
        string_client_only["aud"] = json!(CLIENT);
        let mut azp_smuggled = payload_at(NOW);
        azp_smuggled.as_object_mut().expect("object").remove("aud");
        azp_smuggled["azp"] = json!(CLIENT);
        for payload in [no_client, no_eve_online, string_client_only, azp_smuggled] {
            assert!(matches!(
                verify(&token_with(payload), &keys),
                Err(AuthError::InvalidClaims("audience"))
            ));
        }
    }

    // Case 6: missing/zero exp and future nbf.
    #[test]
    fn missing_exp_and_future_nbf() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let token_with = |payload: Value| {
            make_token(header("RS256", "rsa-1"), payload, |input| {
                sign_rs256(&private, input)
            })
        };
        let mut missing_exp = payload_at(NOW);
        missing_exp.as_object_mut().expect("object").remove("exp");
        assert!(matches!(
            verify(&token_with(missing_exp), &keys),
            Err(AuthError::InvalidClaims("missing_exp"))
        ));
        let mut zero_exp = payload_at(NOW);
        zero_exp["exp"] = json!(0);
        assert!(matches!(
            verify(&token_with(zero_exp), &keys),
            Err(AuthError::InvalidClaims("missing_exp"))
        ));
        let mut future_nbf = payload_at(NOW);
        future_nbf["nbf"] = json!(NOW + 3600);
        assert!(matches!(
            verify(&token_with(future_nbf), &keys),
            Err(AuthError::InvalidClaims("not_yet_valid"))
        ));
        // nbf exactly at now + leeway is acceptable.
        let mut boundary_nbf = payload_at(NOW);
        boundary_nbf["nbf"] = json!(NOW + JWT_LEEWAY_SECS);
        assert!(verify(&token_with(boundary_nbf), &keys).is_ok());
    }

    // Case 7: `alg: "none"`. jsonwebtoken 12 has no `none`
    // algorithm variant, so header parsing itself fails and
    // the token is MalformedToken (design allows either that
    // or InvalidSignature; never Ok). An RS256 header with an
    // empty signature is InvalidSignature.
    #[test]
    fn alg_none_and_empty_signature() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let none_token = make_token(header("none", "rsa-1"), payload_at(NOW), |_| String::new());
        assert!(matches!(
            verify(&none_token, &keys),
            Err(AuthError::MalformedToken)
        ));
        let empty_sig = make_token(header("RS256", "rsa-1"), payload_at(NOW), |_| String::new());
        let _ = private;
        assert!(matches!(
            verify(&empty_sig, &keys),
            Err(AuthError::InvalidSignature)
        ));
    }

    // Case 8: algorithm confusion. The key decides the
    // algorithm; every mismatched header is InvalidSignature.
    #[test]
    fn algorithm_mismatch_and_hs_forgery() {
        let (private, rsa_jwk) = rsa_fixture("rsa-1");
        let (signing, ec_jwk) = ec_fixture("ec-1");
        let keys = keys_from(&jwks_of(&[rsa_jwk.clone(), ec_jwk]));
        // ES256 header against the RSA key.
        let es_header_rsa_key = make_token(header("ES256", "rsa-1"), payload_at(NOW), |input| {
            sign_es256(&signing, input)
        });
        assert!(matches!(
            verify(&es_header_rsa_key, &keys),
            Err(AuthError::InvalidSignature)
        ));
        // RS256 header against the EC key.
        let rs_header_ec_key = make_token(header("RS256", "ec-1"), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        assert!(matches!(
            verify(&rs_header_ec_key, &keys),
            Err(AuthError::InvalidSignature)
        ));
        // HS256 forged with the RSA public modulus as the HMAC
        // secret (the classic alg-confusion attack).
        let modulus_b64 = rsa_jwk["n"].as_str().expect("modulus").to_string();
        let modulus = URL_SAFE_NO_PAD.decode(modulus_b64).expect("modulus bytes");
        let forged = make_token(header("HS256", "rsa-1"), payload_at(NOW), |input| {
            sign_hs256(&modulus, input)
        });
        assert!(matches!(
            verify(&forged, &keys),
            Err(AuthError::InvalidSignature)
        ));
    }

    // Case 9: tampered payload and wrong-key signature.
    #[test]
    fn tampered_payload_and_wrong_key() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let (other_private, _other_jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        let signed = make_token(header("RS256", "rsa-1"), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        let mut segments: Vec<&str> = signed.split('.').collect();
        let mut tampered_payload = payload_at(NOW);
        tampered_payload["sub"] = json!("CHARACTER:EVE:99999");
        let tampered_segment = b64(tampered_payload.to_string().as_bytes());
        segments[1] = &tampered_segment;
        let tampered = segments.join(".");
        assert!(matches!(
            verify(&tampered, &keys),
            Err(AuthError::InvalidSignature)
        ));
        let wrong_key = make_token(header("RS256", "rsa-1"), payload_at(NOW), |input| {
            sign_rs256(&other_private, input)
        });
        assert!(matches!(
            verify(&wrong_key, &keys),
            Err(AuthError::InvalidSignature)
        ));
    }

    // Case 10: malformed tokens.
    #[test]
    fn malformed_tokens() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let keys = keys_from(&jwks_of(&[jwk]));
        for bad in ["not-a-jwt", "a.b", "a.!!!.c"] {
            assert!(matches!(verify(bad, &keys), Err(AuthError::MalformedToken)));
        }
        let no_kid = make_token(json!({"alg": "RS256"}), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        assert!(matches!(
            verify(&no_kid, &keys),
            Err(AuthError::MalformedToken)
        ));
        let empty_kid = make_token(header("RS256", ""), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        assert!(matches!(
            verify(&empty_kid, &keys),
            Err(AuthError::MalformedToken)
        ));
        // Validly signed but the payload is not JSON.
        let signing_input = format!(
            "{}.{}",
            b64(header("RS256", "rsa-1").to_string().as_bytes()),
            b64(b"not-json")
        );
        let non_json = format!("{signing_input}.{}", sign_rs256(&private, &signing_input));
        assert!(matches!(
            verify(&non_json, &keys),
            Err(AuthError::MalformedToken)
        ));
    }

    // Case 11: unknown/duplicate kid, and the usable-key filter.
    #[test]
    fn unknown_duplicate_kid_and_unusable_keys() {
        let (private, rsa_jwk) = rsa_fixture("rsa-1");
        let (_signing, ec_jwk) = ec_fixture("ec-1");
        let keys = keys_from(&jwks_of(std::slice::from_ref(&rsa_jwk)));
        let unknown = make_token(header("RS256", "nope"), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        assert!(matches!(
            verify(&unknown, &keys),
            Err(AuthError::UnknownSigningKey)
        ));
        let duplicated = keys_from(&jwks_of(&[rsa_jwk.clone(), rsa_jwk.clone()]));
        let token = make_token(header("RS256", "rsa-1"), payload_at(NOW), |input| {
            sign_rs256(&private, input)
        });
        assert!(matches!(
            verify(&token, &duplicated),
            Err(AuthError::UnknownSigningKey)
        ));
        // Parse-level: every unusable shape is dropped, the two
        // usable keys survive in order.
        let mixed = jwks_of(&[
            json!({"kty": "oct", "kid": "oct-1", "k": "AA"}),
            json!({"kty": "EC", "crv": "P-384", "kid": "p384-1", "x": "AA", "y": "AA"}),
            json!({"kty": "RSA", "kid": "enc-1", "use": "enc", "n": "AA", "e": "AQAB"}),
            json!({"kty": "RSA", "kid": "alg-1", "alg": "ES256", "n": "AA", "e": "AQAB"}),
            json!({"kty": "RSA", "kid": "noexp-1", "n": "AA"}),
            json!({"kty": "RSA", "n": "AA", "e": "AQAB"}),
            rsa_jwk,
            ec_jwk,
        ]);
        let usable: Vec<String> = keys_from(&mixed)
            .iter()
            .map(|key| key.kid().to_string())
            .collect();
        assert_eq!(usable, vec!["rsa-1".to_string(), "ec-1".to_string()]);
    }

    /// Sequence JWKS mock in the `src/esi/client.rs` mock style:
    /// serves the Nth queued response to the Nth connection and
    /// counts hits, so refetch behaviour is observable.
    struct MockJwks {
        url: String,
        hits: Arc<AtomicUsize>,
        requests: Arc<Mutex<Vec<String>>>,
    }

    async fn mock_jwks(responses: Vec<(u16, String, String)>) -> MockJwks {
        let listener = TcpListener::bind("127.0.0.1:0")
            .await
            .expect("bind mock jwks");
        let addr = listener.local_addr().expect("addr");
        let queue = Arc::new(Mutex::new(VecDeque::from(responses)));
        let hits = Arc::new(AtomicUsize::new(0));
        let requests = Arc::new(Mutex::new(Vec::new()));
        let (hits_task, requests_task, queue_task) =
            (hits.clone(), requests.clone(), queue.clone());
        tokio::spawn(async move {
            while let Ok((mut socket, _peer)) = listener.accept().await {
                hits_task.fetch_add(1, Ordering::SeqCst);
                let mut buffer = vec![0u8; 16384];
                let count = socket.read(&mut buffer).await.unwrap_or(0);
                if let Ok(mut captured) = requests_task.lock() {
                    captured.push(String::from_utf8_lossy(&buffer[..count]).into_owned());
                }
                let (status, extra_headers, body) = queue_task
                    .lock()
                    .ok()
                    .and_then(|mut queued| queued.pop_front())
                    .unwrap_or_else(|| (500, String::new(), String::new()));
                let payload = format!(
                    "HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\n{extra_headers}Content-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = socket.write_all(payload.as_bytes()).await;
                let _ = socket.flush().await;
            }
        });
        MockJwks {
            url: format!("http://{addr}/oauth/jwks"),
            hits,
            requests,
        }
    }

    fn verifier_at(url: String) -> JwtVerifier {
        JwtVerifier::with_endpoint(reqwest::Client::new(), url, CLIENT.to_string())
    }

    fn live_token(private: &PrivateKey) -> String {
        make_token(header("RS256", "rsa-1"), payload_at(now_unix()), |input| {
            sign_rs256(private, input)
        })
    }

    // Case 12: unknown kid, then exactly one refetch succeeds.
    // The first JWKS carries a different usable key (an empty
    // key set would be a fetch failure, not an unknown-kid
    // miss); the second carries the token's key.
    #[tokio::test]
    async fn unknown_kid_refetch_success() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let (_other, other_jwk) = rsa_fixture("other-1");
        let mock = mock_jwks(vec![
            (200, String::new(), jwks_of(&[other_jwk])),
            (200, String::new(), jwks_of(&[jwk])),
        ])
        .await;
        let verifier = verifier_at(mock.url.clone());
        let token = live_token(&private);
        let claims = verifier.verify(&token).await.expect("refetch verifies");
        assert_eq!(claims.character_id(), Some(12345));
        assert_eq!(mock.hits.load(Ordering::SeqCst), 2);
        let captured = mock.requests.lock().expect("captured").join("\n");
        assert!(!captured.to_lowercase().contains("authorization"));
    }

    // Case 13: kid still unknown after the one refetch.
    #[tokio::test]
    async fn unknown_kid_after_refetch() {
        let (private, _jwk) = rsa_fixture("rsa-1");
        let (_other, other_jwk) = rsa_fixture("other-1");
        let other_body = jwks_of(&[other_jwk]);
        let mock = mock_jwks(vec![
            (200, String::new(), other_body.clone()),
            (200, String::new(), other_body),
        ])
        .await;
        let verifier = verifier_at(mock.url.clone());
        let token = live_token(&private);
        assert!(matches!(
            verifier.verify(&token).await,
            Err(AuthError::UnknownSigningKey)
        ));
        assert_eq!(mock.hits.load(Ordering::SeqCst), 2);
    }

    // Case 14: a fresh cache serves repeat verifies.
    #[tokio::test]
    async fn cache_reuse() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let mock = mock_jwks(vec![(200, String::new(), jwks_of(&[jwk]))]).await;
        let verifier = verifier_at(mock.url.clone());
        let token = live_token(&private);
        verifier.verify(&token).await.expect("first verify");
        verifier.verify(&token).await.expect("cached verify");
        assert_eq!(mock.hits.load(Ordering::SeqCst), 1);
    }

    // Case 15: expired cache plus a failed refetch fails
    // closed even though the kid was cached.
    #[tokio::test]
    async fn expired_cache_failed_refetch_fails_closed() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let mock = mock_jwks(vec![
            (200, String::new(), jwks_of(&[jwk])),
            (500, String::new(), String::new()),
        ])
        .await;
        let verifier = verifier_at(mock.url.clone()).with_ttl_override(Duration::ZERO);
        let token = live_token(&private);
        verifier.verify(&token).await.expect("first verify");
        assert!(matches!(
            verifier.verify(&token).await,
            Err(AuthError::JwksUnavailable)
        ));
        assert_eq!(mock.hits.load(Ordering::SeqCst), 2);
    }

    // Case 16: JWKS endpoint failures, and Cache-Control
    // max-age honoured with the 3600 s cap.
    #[tokio::test]
    async fn jwks_errors_and_ttl_cap() {
        let (private, jwk) = rsa_fixture("rsa-1");
        let token = live_token(&private);
        for (status, body) in [
            (500, String::new()),
            (200, "not json".to_string()),
            (200, jwks_of(&[])),
            (
                200,
                jwks_of(&[json!({"kty": "oct", "kid": "oct-1", "k": "AA"})]),
            ),
        ] {
            let mock = mock_jwks(vec![(status, String::new(), body)]).await;
            let verifier = verifier_at(mock.url.clone());
            assert!(matches!(
                verifier.verify(&token).await,
                Err(AuthError::JwksUnavailable)
            ));
        }
        let mock = mock_jwks(vec![(
            200,
            "Cache-Control: max-age=999999\r\n".to_string(),
            jwks_of(std::slice::from_ref(&jwk)),
        )])
        .await;
        let verifier = verifier_at(mock.url.clone());
        verifier
            .verify(&token)
            .await
            .expect("verify with capped ttl");
        let cached_ttl = verifier.lock_cache().as_ref().expect("cache populated").ttl;
        assert_eq!(cached_ttl, Duration::from_secs(JWKS_MAX_TTL_SECS));
        let mock = mock_jwks(vec![(
            200,
            "Cache-Control: public, max-age=120\r\n".to_string(),
            jwks_of(&[jwk]),
        )])
        .await;
        let verifier = verifier_at(mock.url.clone());
        verifier.verify(&token).await.expect("verify with ttl");
        let cached_ttl = verifier.lock_cache().as_ref().expect("cache populated").ttl;
        assert_eq!(cached_ttl, Duration::from_secs(120));
    }
}
