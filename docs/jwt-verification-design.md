# JWT Signature Verification — Design

Status: implemented on `feat/jwt-signature-verification`
(verification module, trust-point wiring, and integrator finish
all committed locally; not pushed or merged). The live-account
matrix in Section 11 gate 6 has not been run against a real EVE
account yet. The text below is the design as approved; two
version adaptations (jsonwebtoken 12 clock and `alg=none`
handling) are recorded in the implementing commit body and in
`docs/engineering-journal/LEARNINGS.md`.
Repo: `/home/jefcox/workspace/infiquetra/mimir`, branch
`feat/jwt-signature-verification` off `develop` at 9d21bb7
(conversion #561, Assets #562, step-up #563 all merged). Every
`file:line` reference below was read in full at that commit.
External EVE facts are from CCP's "Validating JWT tokens from the
EVE SSO" (esi-docs, fetched for this design; source URL in
Section 3).

## 1. What this solves, in plain terms

Every EVE access token is a JWT (JSON Web Token): a signed JSON
payload naming the character (`sub`), the granted scopes (`scp`),
and an expiry (`exp`). Mimir currently **decodes that payload
without checking the signature** and trusts it to decide which
character's tokens to save, which scopes were granted, and when
the token expires. The code says so itself: `JwtClaims` is
documented as "JWT claims parsed without signature verification
(same as Flutter; JWKS verification is a named hardening
follow-up)" (`src/auth/oauth.rs:145-146`), `parse_jwt_claims` is
"Decode the claims segment of a JWT (no signature check, as in
Flutter)" (`src/auth/oauth.rs:344-345`), and the rewrite design
named the gap: "JWT signature is not verified (faithful port of
Flutter); add JWKS verification against `login.eveonline.com` as
a hardening follow-up" (`docs/rust-rewrite-design.md:277-278`).
The step-up design deliberately left it out of its slice
(`docs/stepup-oauth-design.md:489-493`). This slice is that
follow-up.

The risk being closed, stated concretely: anything that can get
a forged or tampered token response in front of Mimir (a
compromised or impersonated token endpoint, a TLS failure mode,
a malicious local proxy) can today make Mimir save tokens under
an arbitrary character id, record arbitrary granted scopes in
`token_meta`, and set an arbitrary expiry — because the character
id, scope list, and expiry all come from the unverified payload.
After this slice, a token is only trusted after its signature
verifies against EVE's published JWKS (JSON Web Key Set) and its
issuer, audience, and expiry validate.

### Fail-closed contract (applies to every section below)

Verification **fails closed**. Any of the following rejects the
token and saves nothing — no `TokenStore::save`, no
`set_token_meta`, no character row change:

- any signature-verification error;
- an unknown `kid` still unknown after exactly one JWKS refetch;
- an expired JWKS cache whose refetch fails (no stale-key use);
- wrong issuer, wrong audience, wrong or key-mismatched
  algorithm, missing/expired `exp`, future `nbf`;
- a malformed token, header, payload, or JWKS document.

There is no "warn and continue", no fall back to the unverified
`parse_jwt_claims`, and no partial save. The one consequence to
state plainly: a transient JWKS outage now makes sign-in (and
token refresh, Section 2 T4) fail until JWKS is reachable again.
That is the accepted price of failing closed, and the error the
user sees says sign-in failed (Section 7), never a silent
success.

### What verification does not change

- Tokens still arrive only over the existing HTTPS token-endpoint
  exchange/refresh (`exchange_code` / `refresh_with`,
  `src/auth/oauth.rs:399-482`); verification is an added gate
  between receipt and storage, not a new token source.
- ESI itself re-validates every token server-side on each call.
  Local verification protects Mimir's *local* trust decisions
  (character keying, scope bookkeeping, expiry timing); it is
  not a substitute for, and does not change, any ESI behaviour.

## 2. Trust-point inventory (inspected at 9d21bb7)

A "trust point" is any place a value that originated in JWT
claims drives a decision. The whole `src/` tree was grepped for
`parse_jwt_claims`, `JwtClaims`, `claims`, and `expiry_for`.
There are exactly **three production `parse_jwt_claims` call
sites** (`src/app/shell.rs:826`, `src/app/shell.rs:990`, and
`expiry_for` at `src/auth/oauth.rs:528`) feeding **seven trust
points**. There is no JWT parsing anywhere else: no `aud` or
`nbf` field exists on `JwtClaims` yet (`src/auth/oauth.rs:147-163`
carries `sub`, `name`, `exp`, `iat`, `scp`, `iss`, `owner`), and
nothing in `src/` mentions JWKS today.

| # | Site (file:line) | Claims fields consumed | What they drive | Verify in this slice? |
|---|---|---|---|---|
| T1 | First-login tail, `src/app/shell.rs:826-852` (spawned task in `start_login`) | `sub` via `character_id()` (:827-829); `scp` (:837); `exp` (:838); `name` (:844-848) | The character id the tokens are saved under (`StoredTokens::from_token_response` :830 → `token_store.save` :831); `token_meta.scopes`/`expires_at` (:833-841); the displayed `CharacterRow.name` (:842-852) | **Yes — required.** Verify `tokens.access_token` immediately after `exchange_code` (:825), before *any* claims field is read. |
| T2 | Step-up tail, `src/app/shell.rs:990-1038`, plus `validate_expected_character` (`src/auth/oauth.rs:118-143`) | `sub` (:991-992); `scp` (:993, :1034); `exp` (:1035) | Whether the returned token belongs to the expected character; the grant-proof `missing_scopes(&claims.scp, &expected_scopes)` (:993) that decides save-vs-abort; `token_meta` after save (:1030-1038) | **Yes — required.** Verify immediately after `exchange_code` (:989), before `validate_expected_character`. The character/scope checks keep their current logic but run on verified claims. |
| T3 | `expiry_for` (`src/auth/oauth.rs:527-534`) reached via `StoredTokens::from_token_response` (`src/auth/token_store.rs:71-79`) from both login tails | `exp` (:528-531) | `StoredTokens.expires_at_unix` persisted with the tokens, i.e. when Mimir thinks the access token dies | **Yes — by construction.** The stored expiry is taken from the *already-verified* claims of T1/T2 (Section 8.2); `expiry_for`'s own unverified re-parse is removed from this path. |
| T4 | `expiry_for` (`src/auth/oauth.rs:527-534`) reached via `StoredTokens::apply_refresh` (`src/auth/token_store.rs:83-93`) from `EsiClient::valid_access_token` (`src/esi/client.rs:172-201`) after `oauth::refresh_with` (:186-196) | `exp` (today: not even parsed except inside `expiry_for`; no claims check exists on this path at all today) | The rotated access/refresh tokens are persisted (`store.save` :198) and their expiry recorded. The character key is the *stored* `character_id` argument, not derived from claims | **Yes — required.** Verify the refreshed access token before `apply_refresh`/`save`, and additionally require its verified `character_id()` to equal the stored character id. Reasoning and the rejected "bounded lower-risk" alternative: below. |
| T5 | `JwtClaims::is_expired_at` (`src/auth/oauth.rs:175-177`) | `exp` | Nothing in production: grep shows only test callers (`src/auth/oauth.rs:576,581`). | **No — bounded.** Pure predicate on a claims value the caller supplies; after this slice every production `JwtClaims` that matters is a verified one. It gains no new caller. |
| T6 | Step-up pre-check reads `token_meta.scopes` from the database (`src/app/shell.rs:907-935`) | Persisted derivative of `scp`, written at T1/T2 | Only the browser-vs-refresh decision (`missing_scopes`, :935); the typed 403 from the real assets fetch remains the authority for showing the panel (step-up design S3, `docs/stepup-oauth-design.md:99`) | **No — bounded.** This is stored database state, not a live JWT. Pre-existing rows were written from unverified claims; the worst case is one redundant or one skipped browser trip, never a wrong save, because the save path (T2) now verifies. Explicitly accepted; no migration or backfill (hard scope). |
| T7 | `StoredTokens::needs_refresh_at` (`src/auth/token_store.rs:95-101`) + `needs_refresh` (`src/auth/oauth.rs:360-362`) | Stored `expires_at_unix` (derived from `exp` at T3/T4) | Refresh *timing* only: refresh early or late. A wrong value cannot change which character a token belongs to; ESI 401s bound the damage of a too-late refresh | **No — bounded.** After this slice the value it reads is written only from verified `exp`. |

### Why T4 (refresh) must verify, and not be bounded as lower-risk

The "bounded lower-risk" reading of T4 is real and was
considered: the refreshed token is keyed to the already-stored
character, claims do not choose the key, and ESI would reject a
forged token on first use. It is rejected for three inspected
reasons:

1. T4 *persists* tokens (`store.save`, `src/esi/client.rs:198`),
   including a rotated refresh token. "Saves nothing on
   verification failure" (the fail-closed contract) only holds
   app-wide if every token-receipt path verifies; leaving the
   most frequently exercised receipt path unverified would make
   the guarantee false in the common case.
2. `expiry_for` trusts the unverified `exp` today
   (`src/auth/oauth.rs:528-531`): a forged far-future `exp`
   stops all future refreshes until the token dies server-side.
3. The step-up grant-proof (T2) trusts `scp` from a token that
   may have arrived via refresh-persisted state history; one
   verifier used at all three receipt points keeps the trust
   story to a single sentence: *no access token is saved before
   it verifies.*

One T4 consequence, stated honestly: EVE rotates refresh
tokens. If a refreshed access token fails verification, the
whole refresh response — including any new refresh token — is
dropped (nothing saved). If EVE has already retired the old
refresh token, the next refresh fails with the existing
`RefreshRejected` → `EsiError::Reauthorize` mapping
(`src/esi/client.rs:193-196`) and the user re-authorizes. That
is fail-closed working as specified, not data loss to engineer
around in this slice.

### Existing shapes this design reuses (inspected)

- Injected-endpoint seams are the codebase pattern:
  `exchange_code_with(http, token_endpoint, client_id, ...)`
  (`src/auth/oauth.rs:399-423`), `refresh_with` (:439-471),
  `EsiClient::with_http` / `with_token_endpoint(endpoint, client_id)`
  (`src/esi/client.rs:61-88`). The verifier follows the same
  shape (Section 8).
- `TokenResponse` redacted `Debug` (`src/auth/oauth.rs:194-203`),
  `expires_at_unix` `expires_in` fallback (:208-215), and
  `validate()` (:217-225) are unchanged.
- `deserialize_scp` already handles EVE's string-or-array claim
  shape for `scp` (`src/auth/oauth.rs:42-56`); Section 5 adds
  the analogous (but not whitespace-splitting) shape for `aud`.
- Loopback mock HTTP servers in tests:
  `mock_server` (`src/esi/client.rs:346-368`) and the servers in
  `src/esi/endpoints.rs:419,491,524`. Section 9 extends that
  style; it invents no new test HTTP dependency.
- `fake_jwt` (`src/auth/oauth.rs:562-566`) builds *unsigned*
  fixture tokens ending in the literal `.sig`. It remains valid
  for `parse_jwt_claims` parser tests only; it must never be
  used to claim verification works (Section 9).

## 3. JWKS discovery (Decision J1)

EVE's own validation guide (CCP esi-docs, "Validating JWT
tokens from the EVE SSO",
`https://docs.esi.evetech.net/docs/sso/validating_eve_jwt.html`,
fetched for this design) states:

- the SSO metadata endpoint is
  `https://login.eveonline.com/.well-known/oauth-authorization-server`
  and it "provides a link to the SSO JWT key set which is
  currently located at `https://login.eveonline.com/oauth/jwks`";
- "Currently the SSO uses the RS-256 signature method, but will
  also support ES-256 in the near future";
- the issuer is either the host name or the URI (`Section 5`);
- `aud` must include both the `client_id` and `"EVE Online"`,
  and its example payload shows `aud` as a JSON array
  containing exactly those two values.

**Locked decision J1 — fetch JWKS directly from a config
constant; do not fetch the metadata document at runtime in this
slice.** Runtime metadata discovery would add a second fetch
and failure mode, and its output could not be trusted blindly
anyway (a `jwks_uri` pointing anywhere other than the EVE host
would still have to be allowlist-checked against the same host
knowledge the constant already encodes). The metadata URL is
recorded as a constant and a comment so a future slice can add
discovery and so the JWKS constant's provenance is auditable.

Configuration today has no JWKS or metadata constant. The auth
endpoint constants live at `src/config.rs:13-16`
(`OAUTH_AUTHORIZE_URL`, `OAUTH_TOKEN_URL`, `OAUTH_REVOKE_URL`,
`OAUTH_HOST = "login.eveonline.com"`), all on the one host.
Builder A adds exactly two additive constants beside them
(no existing constant is edited; `CLIENT_ID` at
`src/config.rs:23` is the existing public PKCE client id —
cited by location here, its value is not reproduced):

```rust
/// SSO metadata document (provenance for OAUTH_JWKS_URL; not
/// fetched at runtime in this slice — see JWT design J1).
pub const OAUTH_METADATA_URL: &str =
    "https://login.eveonline.com/.well-known/oauth-authorization-server";
/// JWKS for EVE SSO access-token signatures, as linked from
/// OAUTH_METADATA_URL per CCP's JWT validation guide.
pub const OAUTH_JWKS_URL: &str = "https://login.eveonline.com/oauth/jwks";
```

Rules:

- Production code obtains the JWKS URL **only** from
  `EveConfig::OAUTH_JWKS_URL` (default constructor, Section 8).
  No module invents or string-builds a JWKS URL from parts.
- Tests override it exactly the way the codebase already
  overrides the token endpoint: by injecting an endpoint string
  into a `*_with`-style constructor
  (`JwtVerifier::with_endpoint(http, jwks_url, client_id)`,
  Section 8), mirroring `refresh_with(http, token_endpoint,
  client_id, ...)` (`src/auth/oauth.rs:439-444`) and
  `EsiClient::with_token_endpoint` (`src/esi/client.rs:83-88`).
  The injected value in tests is a loopback `http://127.0.0.1:<port>/...`
  URL from the mock server; production never constructs the
  verifier that way.
- The JWKS fetch is a plain GET over the verifier's injected
  `reqwest::Client` (production: same builder shape as
  `default_http`, `src/auth/oauth.rs:364-371` — 30 s timeout
  from `EveConfig::DEFAULT_TIMEOUT_MS`, `EveConfig::USER_AGENT`,
  rustls TLS per `Cargo.toml:11`). No `Host` header override:
  that trick exists on the token endpoints
  (`src/auth/oauth.rs:407,446,492`) for the real EVE endpoint;
  the JWKS URL's own host is the TLS host, and test loopback
  servers need no override. Builder A does not replicate it.
- A non-2xx status, a transport error, an unparseable body, or
  a body with zero usable keys is `AuthError::JwksUnavailable`
  (Section 7). The response body (public keys only, but still)
  is never logged; key count and `kid` values may be logged
  (public, Section 10).

## 4. Verification dependency (Decision J2)

Hard constraints first: at most **one** new runtime dependency;
**no OpenSSL-linked dependency** (rustls / ring / RustCrypto
only, matching `reqwest` rustls at `Cargo.toml:11`); must
support RS256 now and ES256 when EVE enables it; must be safe
against algorithm confusion (the verifier, never the token
header, chooses the algorithm). Current crypto-adjacent
dependencies are only `sha2 0.10`, `base64 0.22`, `rand 0.8`
(`Cargo.toml:17-19`); `oauth2 4` (`Cargo.toml:16`) is a client
flow library with no JWT signature verification and is not used
anywhere in `src/` today, so it solves nothing here.

| Candidate | RS256 + ES256 | JWK handling | OpenSSL | Alg-confusion safety | Verdict |
|---|---|---|---|---|---|
| **`jsonwebtoken`** (Keats) with its **`rust_crypto`** backend feature | Both, via RustCrypto `rsa` + `p256` under the one direct dependency | `DecodingKey::from_rsa_components(n, e)` / `from_ec_components(x, y)` consume the base64url JWK components directly; JWKS document parsing itself is plain `serde_json` in our module (a `keys` array of small structs — no second dep needed) | None with `rust_crypto`. (Its alternate `aws_lc_rs` backend is **not** selected; aws-lc is a BoringSSL fork and is outside the rustls/ring/RustCrypto list in spirit and review surface.) `cargo tree` must prove no `openssl-sys` (Section 11). | `Validation::new(alg)` pins the expected algorithm; decode rejects a header algorithm that differs. Our code derives that pinned algorithm from the *selected JWK's key type*, never from the header (Section 5). | **Selected — the one new runtime dependency.** |
| Manual verification with `rsa` + `p256` (+ hand-rolled JWS) | Both, but as **two** new direct runtime dependencies — already over the hard cap before counting anything else | Hand-rolled: base64url segment splitting, ASN.1/component wrangling, PKCS#1 v1.5 padding, ECDSA `r‖s` handling, all ours to get wrong | None (RustCrypto) | Entirely hand-rolled — the exact bug class (alg confusion, padding oracles, non-constant-time compares, `none` acceptance) that maintained JWT libraries exist to have already survived | **Rejected.** Violates the one-dependency cap and maximizes hand-rolled-crypto risk for zero benefit. |
| `biscuit` (JOSE/JWT on `ring`) | Both via ring | Full JWK/JWKS types | None (ring) | Sound JOSE handling, but claims validation (iss/aud/exp/nbf, required-claim presence) is largely left to the caller, and its builder/claims API is a larger, less commonly used surface than `jsonwebtoken`'s | **Rejected.** Viable crypto, but more validation logic hand-written in our code and a second-choice ecosystem position; no advantage over the selected crate on any stated criterion. |
| A dedicated JWKS client crate on top of a JWT crate (e.g. `jwks`-style helpers) | Delegates to underlying JWT crate | Yes, plus fetching/caching | Depends on stack | Delegates | **Rejected.** Two direct dependencies (JWT + JWKS helper) for a fetch-and-cache we must anyway control precisely (TTL source, fail-closed expiry, exactly-one-refetch). The helper's cache policy would have to be fought, not reused. |

**Locked decision J2:** Builder A adds exactly one runtime
dependency:

```toml
jsonwebtoken = { version = "<current stable major>", default-features = false, features = ["rust_crypto"] }
```

Builder A pins the current stable major whose API provides
`decode_header`, `DecodingKey::from_rsa_components`,
`DecodingKey::from_ec_components`, `Validation::new` with
audience/issuer/required-claims/leeway configuration, and
records the exact chosen version in the commit message body.
`default-features = false` keeps the PEM-parsing default
(`use_pem`) off unless the pinned version's component
constructors need it — verification from JWK components should
not; if it does, Builder A enables `use_pem` and says so in the
commit. If the pinned version's constructor or `Validation`
names differ from those above, Builder A adapts the *call
sites* — the validation semantics in Section 5 do not change.
Transitive dependencies pulled by `jsonwebtoken` +
`rust_crypto` (notably `rsa`, `p256`, `sha2`, signature traits)
are its internals, not additional direct dependencies of
Mimir; the integrator proves `openssl-sys` is absent from the
whole tree (Section 11).

Dev-dependencies for test keys are addressed in Section 9;
they are test-only and justified there.

## 5. Validation rules (Decision J3)

Verification is one ordered pipeline. Steps 1–3 use only the
*header* (for key selection); no claims field is trusted or
even returned until step 5 succeeds. The pure core is
`verify_with_keys(token, &keys, client_id, now_unix_secs)`
(Section 8); the async wrapper only supplies it with keys.

1. **Structure.** Split must yield a parseable JOSE header
   (`jsonwebtoken::decode_header` or the pinned equivalent).
   Any failure → existing `AuthError::MalformedToken`
   (`src/error.rs:112-113`), the same variant malformed tokens
   produce today (`src/auth/oauth.rs:348-356`).
2. **`kid` required.** Header `kid` must be present and
   non-empty, else `MalformedToken`. A `kid` inside the payload
   (EVE's guide example payload prints one) is **not** a
   substitute; key selection reads the header only.
3. **Key selection by `kid`.** Look the `kid` up in the current
   usable key set (Section 6 defines *usable*). Zero matches →
   `AuthError::UnknownSigningKey` *after* the async wrapper has
   done its one allowed refetch (Section 6); the pure core just
   reports the miss. **More than one usable key with the same
   `kid` → reject as `UnknownSigningKey`** (ambiguous key sets
   are never resolved by trying each key — trying-each-key
   turns signature verification into an oracle and hides a
   broken JWKS).
4. **Algorithm pinned by the selected key, never the header.**
   - `kty == "RSA"` → the only accepted algorithm is RS256;
     `DecodingKey` from the JWK `n`/`e` components.
   - `kty == "EC"` **and** `crv == "P-256"` → the only accepted
     algorithm is ES256; `DecodingKey` from `x`/`y`.
   - Any other `kty`/`crv` (including `oct`, P-384, EdDSA keys)
     → the key is unusable, excluded at JWKS parse time.
   - If the JWK carries a `use` field it must be `"sig"`; if it
     carries an `alg` field it must equal the algorithm derived
     above; otherwise the key is unusable.
   - The header `alg` must equal the key-derived algorithm,
     checked explicitly **and** by constructing the library
     `Validation` for exactly that one algorithm. A mismatch
     (including `alg: "none"`, an empty signature, or an RSA
     key presented with an ES256/HS256 header) →
     `AuthError::InvalidSignature`. This double check is the
     alg-confusion defence: even a library quirk cannot make an
     RSA public key be used as an HMAC secret, because no HMAC
     algorithm is ever constructed.
5. **Signature + claims decode** in one library `decode` call
   against an internal verified-claims struct (below), with
   temporal validation evaluated at the injected `now`.
   Library signature failure → `InvalidSignature`; library
   temporal failure → mapped as in step 8 (Builder A maps the
   pinned version's error kinds explicitly, no catch-all that
   could swallow a signature error into a claims error or vice
   versa).
6. **Issuer.** `iss` is required and must be *exactly* one of
   `login.eveonline.com` or `https://login.eveonline.com` —
   the two spellings CCP's guide names. Builder A constructs
   the accepted set from `EveConfig::OAUTH_HOST`
   (`src/config.rs:16`) as `{host, https://host}` rather than
   repeating literals in the verifier module. Test tokens must
   therefore carry one of these two issuers too (they are
   inputs the test signs, not an endpoint override). Missing
   or different → `AuthError::InvalidClaims("issuer")`.
7. **Audience.** `aud` is required. After string-or-array
   normalization (below) it must contain **both** the
   verifier's configured client id (production:
   `EveConfig::CLIENT_ID`, `src/config.rs:23`, by location
   only; tests: the injected `client_id`, mirroring
   `refresh_with`'s parameter) **and** the literal
   `"EVE Online"` — CCP's guide: "`aud` … must include both
   the `client_id` and the string value `"EVE Online"`". This
   both-must-be-present check is done in **our** code on the
   verified claims, not delegated to the library's audience
   check, whose semantics (any-of vs all-of) vary by crate and
   version; the library `Validation` is additionally given the
   client id as its audience as defence in depth. Failure →
   `InvalidClaims("audience")`.
8. **Expiry.** `exp` is **required**, must be a positive
   integer, and must satisfy `now < exp + JWT_LEEWAY_SECS`.
   `nbf`, when present, must satisfy
   `now + JWT_LEEWAY_SECS >= nbf`; absent `nbf` is fine.
   `iat` is neither required nor validated. **Leeway is locked
   at 60 seconds**: `pub const JWT_LEEWAY_SECS: i64 = 60;` in
   the verifier module. Rationale: tokens are verified seconds
   after issuance with a 1199 s lifetime
   (`EveConfig::ACCESS_TOKEN_LIFETIME_SECS`, `src/config.rs:75`);
   60 s absorbs ordinary desktop clock skew without meaningfully
   extending trust, and matches the existing 60 s refresh
   buffer's order of magnitude
   (`TOKEN_REFRESH_BUFFER_SECS`, `src/config.rs:76`).
   Expired → `InvalidClaims("expired")`; future `nbf` →
   `InvalidClaims("not_yet_valid")`; missing/non-positive
   `exp` → `InvalidClaims("missing_exp")` (see the masking
   note below).

### The verified-claims shape

`JwtClaims` today (`src/auth/oauth.rs:147-163`) defaults every
field: `exp: i64` with `#[serde(default)]` turns a *missing*
`exp` into `0`, and `iss` is already `Option<String>`. A
required-`exp` rule cannot be enforced on that shape after the
fact (missing and `0` are indistinguishable — and `0` must
reject anyway, but the design does not rely on that accident).
Locked shape:

- The verifier decodes into a **private** `VerifiedClaims`
  struct in the verifier module where `exp: i64` and
  `iss: String` and `aud` have **no** serde defaults (missing
  field = decode error → rejected), `nbf: Option<i64>`,
  and `sub`/`name`/`iat`/`scp`/`owner` mirror `JwtClaims`
  (including `deserialize_scp` for `scp`).
- On success the verifier returns the existing public
  `JwtClaims`, converted field-for-field, so T1/T2 call-site
  logic (`character_id()`, `validate_expected_character`,
  `missing_scopes(&claims.scp, …)`) is untouched in shape.
- Builder A **additively** extends `JwtClaims` with
  `pub aud: Vec<String>` and `pub nbf: Option<i64>` (both
  `#[serde(default)]`, so existing serde derivations and the
  `..JwtClaims::default()` test construction at
  `src/auth/oauth.rs:710-713` keep compiling). `aud` uses a
  new `deserialize_aud` beside `deserialize_scp`
  (`src/auth/oauth.rs:42-56`): string → one-element vec
  (**not** whitespace-split — a single string audience is one
  audience; this differs from `scp` on purpose), array →
  string elements, anything else → empty vec (which then fails
  the Section 5.7 check — fail closed). `VerifiedClaims` uses
  the same deserializer without the default.
- `azp`, `jti`, `tenant`, `tier`, `region` (present in CCP's
  example payload) are ignored: unknown fields are already
  ignored by the existing derive, and none of them drives a
  Mimir decision. `azp` is explicitly **not** accepted as an
  audience substitute.

## 6. JWKS cache (Decision J4)

- **Location:** in-memory only, inside `JwtVerifier`
  (Section 8) in the new verifier module. A
  `std::sync::Mutex<Option<CachedJwks>>` where `CachedJwks`
  holds the parsed usable keys, `fetched_at: std::time::Instant`,
  and `ttl: std::time::Duration`. Nothing is persisted to disk,
  the database, or `token_meta` (no schema change is allowed,
  and public keys gain nothing from surviving a restart: first
  verification after launch refetches). The one `JwtVerifier`
  instance is shared (Section 8.3) so login and refresh see
  one cache, not two.
- **TTL source:** the JWKS response's `Cache-Control: max-age`
  when present and parseable, clamped to at most 3600 s;
  otherwise `JWKS_DEFAULT_TTL_SECS = 300`. Both constants live
  in the verifier module. Freshness is computed from the
  monotonic `Instant`, never the wall clock, so a clock step
  cannot extend key trust. (Claim *time* validation uses wall
  clock `now_unix()` (`src/config.rs:113-118`) injected as
  `now`; cache *age* uses `Instant`. Two different clocks for
  two different jobs, named as such in code comments.)
- **Normal path:** cache present and age < ttl and `kid` found
  → verify with no network. This is the steady state for
  refresh (T4), which may verify many times per session.
- **Unknown `kid`:** exactly **one** forced refetch that
  bypasses TTL freshness (key rotation is precisely the case
  where fresh-enough cached keys are stale), then one re-lookup.
  Still unknown → `UnknownSigningKey`. Never a loop, never a
  second refetch within one `verify` call. If that refetch
  *fails* → `JwksUnavailable` (not `UnknownSigningKey`: we no
  longer know whether the key exists).
- **Expired cache:** age >= ttl → refetch before use. Refetch
  fails → `JwksUnavailable` and the token is rejected — **the
  expired keys are never used as a fallback**, even if the
  `kid` is present in them. (A failed refetch attempt does not
  clear or extend the cache entry; the next `verify` simply
  tries to refetch again. No negative caching in this slice:
  verification only happens on user-driven sign-in or on
  token-refresh cadence, not in a hot loop.)
- **Empty cache (cold start):** fetch; failure →
  `JwksUnavailable`.
- **Concurrency:** the mutex is never held across an `.await`
  (read keys/age out, drop the guard, fetch, then re-lock to
  store). Two concurrent verifications may therefore both
  fetch once; that is benign and needs no single-flight
  machinery. Last writer wins.
- **Usable key** (parse-time filter, Section 5.4): has a
  non-empty `kid`, is RSA with non-empty `n`/`e` or EC P-256
  with non-empty `x`/`y`, and passes the `use`/`alg` gates.
  Unusable keys are dropped with a `[AUTH]` debug log of the
  public `kid` + reason category (key material itself is
  public but is still not logged; Section 10). A JWKS yielding
  zero usable keys is `JwksUnavailable`. Cache-update rule:
  only a fetch yielding ≥1 usable key replaces the cache
  entry; a zero-usable-key fetch updates nothing. Either way
  the token being verified is rejected (an unknown-`kid`
  refetch that returns zero usable keys surfaces as
  `JwksUnavailable`, per the refetch-failure rule above).

### Testability of time

`JwtVerifier::verify(token)` uses `now_unix()` and the real
`Instant` clock. Tests use two seams, both private/`pub(crate)`
test-facing rather than new public API: the pure
`verify_with_keys(..., now_unix_secs)` for all claim-time cases,
and a test constructor (or builder method) that overrides the
cache TTL to `Duration::ZERO` to force the expired-cache path
deterministically without sleeping. No test sleeps to expire a
cache, and no production code path reads the TTL override.

## 7. Error taxonomy (Decision J5)

Four **additive** variants on `AuthError` (`src/error.rs:90-122`),
added after `MalformedToken` (`:112-113`). No existing variant
is renamed, re-payloaded, or removed; malformed-token cases
keep using `MalformedToken` (Section 5.1–5.2). No variant
carries token material, a raw header/payload, a signature, or a
JWKS body — payloads are `'static` category strings or nothing
(`src/error.rs:1`: "No token values ever enter these").

```rust
#[error("[AUTH] EVE signing keys unavailable; token not verified")]
JwksUnavailable,
#[error("[AUTH] token signed with an unknown key")]
UnknownSigningKey,
#[error("[AUTH] token signature invalid")]
InvalidSignature,
#[error("[AUTH] token claims invalid: {0}")]
InvalidClaims(&'static str),
```

| Variant | Produced when | Logged detail (all public categories) |
|---|---|---|
| `JwksUnavailable` | JWKS fetch transport error / non-2xx / unparseable / zero usable keys; expired cache with failed refetch; unknown-`kid` refetch failure (Section 6) | Fetch status or transport-error category + endpoint *host* only. `warn` under `[AUTH]`. |
| `UnknownSigningKey` | `kid` absent from the usable set after the one refetch, or duplicated `kid` (Section 5.3) | The public `kid` string. `warn` under `[AUTH]`. |
| `InvalidSignature` | Header/key algorithm mismatch, `none`/empty signature, or library signature-verification failure (Section 5.4–5.5) | Public `kid` + expected algorithm + header `alg` category. Never the signature or segments. `warn` under `[AUTH]`. |
| `InvalidClaims(&'static str)` | Issuer, audience, `exp`, or `nbf` rejection (Section 5.6–5.8) | The category is exactly one of `"issuer"`, `"audience"`, `"expired"`, `"not_yet_valid"`, `"missing_exp"` — a closed set of literals in the verifier module, matched exhaustively in tests. `warn` under `[AUTH]` with the category; for issuer failures the log may note which accepted spelling was expected as a category (`host`/`uri`), never the received token value. |

### What the user sees

- **First login and step-up (T1/T2):** unchanged path. The
  spawned tail's `Err(e)` already sends
  `BackendMsg::LoginFailed { message: e.to_string() }`
  (`src/app/shell.rs:859-863` and `:1046-1050`), handled at
  `:525-529` as `AuthState::Error` +
  `"Sign-in failed: {message}"`. A verification rejection
  therefore reads e.g. `Sign-in failed: [AUTH] token signature
  invalid`. No new `BackendMsg` variant, no new UI text, no new
  view. Nothing was saved because verification precedes every
  save (Section 8.2).
- **Refresh (T4):** the error propagates out of
  `valid_access_token` through its existing mapping
  (`src/esi/client.rs:193-196`): only `RefreshRejected` is
  special-cased, everything else becomes `AppError::Auth(…)`
  and surfaces through the existing `RefreshFailed` message
  (`src/app/shell.rs:788-792`, status `"Refresh failed:
  {message}"`, `offline = true`). Previously persisted tokens
  are untouched (T4 verifies *before* `apply_refresh`/`save`).
  No new mapping arm is added in this slice; classifying
  `JwksUnavailable` differently (e.g. "offline") is a named
  follow-up, not silent scope.
- Character-mismatch on refresh (T4's added `character_id`
  equality check) reuses the existing
  `AuthError::CharacterMismatch` (`src/error.rs:96-97`; display
  text mentions step-up, which is cosmetically imperfect for a
  refresh — accepted: renaming or duplicating the variant for
  copy reasons is not worth a taxonomy change, and the
  step-up test at `src/auth/oauth.rs:705-708` must keep
  passing unmodified).

## 8. Module layout and wiring (Decision J6)

### 8.1 The one new file

`src/auth/jwt_verify.rs` — an auth-internal module beside
`oauth.rs` / `token_store.rs` (`src/auth/mod.rs:4-6`), declared
with `pub mod jwt_verify;` and re-exporting `JwtVerifier` in
the style of `src/auth/mod.rs:8-14`. This is not a new
*feature* module or UI view (the hard-scope prohibition): it
is the "verification module" half of the existing auth
subsystem, and `oauth.rs` at 751 lines should not grow a
JWKS cache, a JWK model, and a validation pipeline. It
contains: the JWK/JWKS serde model (private), `CachedJwks`,
`JwtVerifier`, `verify_with_keys`, `JWT_LEEWAY_SECS`,
`JWKS_DEFAULT_TTL_SECS`, `JWKS_MAX_TTL_SECS = 3600`, and its
`#[cfg(test)] mod tests`.

```rust
pub struct JwtVerifier { /* http, jwks_url, client_id, cache, ttl_override (test only) */ }

impl JwtVerifier {
    /// Production: EveConfig::OAUTH_JWKS_URL + CLIENT_ID, default_http-shaped client.
    pub fn new() -> Result<Self, AuthError>;
    /// Injected seam (tests), mirroring refresh_with / with_token_endpoint.
    pub fn with_endpoint(http: reqwest::Client, jwks_url: String, client_id: String) -> Self;
    /// Verify a freshly received access token; Ok carries trusted claims.
    pub async fn verify(&self, token: &str) -> Result<JwtClaims, AuthError>;
}

/// Pure core: no I/O, no clock, no cache. (pub(crate) is enough.)
pub(crate) fn verify_with_keys(
    token: &str,
    keys: &[Jwk],
    client_id: &str,
    now_unix_secs: i64,
) -> Result<JwtClaims, AuthError>;
```

`JwtVerifier::new()` builds its HTTP client the way
`default_http` does (`src/auth/oauth.rs:364-371`); Builder A
may reuse `default_http` by widening it to `pub(crate)` —
that visibility tweak is Builder A's, in `oauth.rs`.
`verify()` implements Section 6 exactly: read cache state →
maybe fetch → `verify_with_keys` → if (and only if) the
failure is the unknown-`kid` miss, one forced refetch and one
retry of `verify_with_keys` → map the outcome. To make
"unknown-`kid` miss" distinguishable inside `verify()` without
string matching, `verify_with_keys` returns
`UnknownSigningKey` for the miss and `verify()` keys the
refetch decision on that variant *plus* a `refetched: bool`
local so it can never refetch twice.

`Debug` for `JwtVerifier` (if derived anywhere) must not print
key material: the JWK model types are private and get no
`Debug` derive exposing components; `kid`-only diagnostic
helpers are used in logs. (Public keys are not secrets — this
is defence-in-depth against accidental bulk dumps, and it
keeps the Section 10 rule absolute and greppable.)

### 8.2 Verified-claims flow at the trust points (Builder B)

- **T1** (`src/app/shell.rs:821-865`): replace line 826,
  `let claims = oauth::parse_jwt_claims(&tokens.access_token)?;`,
  with `let claims = jwt_verifier.verify(&tokens.access_token).await?;`
  using the verifier cloned into the spawned task exactly as
  `token_store`/`db`/`tx` are (`:818-820`). Lines 827–852 are
  otherwise unchanged — they now read verified fields.
- **T2** (`src/app/shell.rs:985-1052`): same replacement at
  line 990 (verifier cloned in beside `token_store`/`db`/`tx`
  at `:977-979`). `validate_expected_character` (:991-992) and
  the scope grant-proof (:993) run unchanged on verified
  claims, still *before* any save, preserving every step-up
  guarantee and the removed-character re-check (`:1009-1026`).
- **T3/T4 expiry source:** `StoredTokens` must stop re-deriving
  expiry from an unverified parse. Builder B changes
  `token_store.rs` so construction takes the verified claims:
  `StoredTokens::from_token_response(character_id, &tokens,
  &claims)` and `apply_refresh(&refreshed, &claims)`, with
  `expires_at_unix = if claims.exp > 0 { claims.exp } else {
  tokens.expires_at_unix(now_unix()) }` — i.e. `expiry_for`'s
  current *logic* (`src/auth/oauth.rs:527-534`) re-homed as
  `expiry_for_verified(tokens: &TokenResponse, claims:
  &JwtClaims) -> i64` in `oauth.rs` (Builder A adds it beside
  `expiry_for`; `expiry_for` itself is kept for its existing
  tests/callers during Builder A's step and removed or left
  with zero production callers by Builder B — the integrator
  greps and records which, Section 11). Since verified claims
  always have `exp > 0` (Section 5.8), the fallback arm is
  defensive only. This also removes the current double-parse
  (shell parses at :826/:990, `expiry_for` parses again at
  `oauth.rs:528`).
- **T4 refresh** (`src/esi/client.rs:181-199`): after
  `refresh_with` succeeds and before `apply_refresh`/`save`:
  `let claims = verifier.verify(&refreshed.access_token).await`
  mapped through the same error conversion as the refresh
  error (`:193-196`), then require
  `claims.character_id() == Some(character_id)` else
  `AuthError::CharacterMismatch` (converted the same way),
  then `tokens.apply_refresh(&refreshed, &claims)`.
  `EsiClient` gains a `jwt_verifier: Option<Arc<JwtVerifier>>`
  field and `with_jwt_verifier(Arc<JwtVerifier>)` builder
  mirroring `with_token_store` (`src/esi/client.rs:76-80`).
  **Absence rule:** if no verifier is attached *and* a refresh
  is actually needed, `valid_access_token` must fail before
  saving — with `AppError` from `AuthError::JwksUnavailable`
  and a `[AUTH]` warn saying the verifier is not wired. It
  must never silently skip verification. (Constructors used
  by tests today — `with_http` at `src/esi/client.rs:372,387`,
  `Default` at `:333-336` — therefore cannot complete an
  authenticated refresh unless a test verifier is attached;
  the existing mock-refresh test at `:419-457` is updated by
  Builder B per Section 9.) A still-valid stored token that
  needs no refresh is returned without verification: it was
  verified when it was saved (or predates this slice — T6/T7
  bounded), and re-verifying on every ESI call would add a
  JWKS dependency to the cached-data path for no new trust
  decision.

### 8.3 One shared verifier instance

`src/main.rs:83-98` builds `TokenStore` + `EsiClient` and hands
`Backends` (`src/app/shell.rs:29-33`) to the shell. Builder B:
constructs one `Arc<JwtVerifier>` there (via `JwtVerifier::new()`;
on construction error — today only an HTTP-client build
failure — log a `[AUTH]` warn and use `None`, matching the
`EsiClient::new()` error arm shape at `src/main.rs:90-97`);
adds `pub jwt_verifier: Option<Arc<JwtVerifier>>` to
`Backends`; attaches the same `Arc` to the ESI client via
`with_jwt_verifier`. Shell login tails read it from
`backends` beside `token_store` (`src/app/shell.rs:818,977`);
if it is `None`, the tail fails before opening the browser
with the existing unavailable-backends style status (mirror
`:800` / `:889-891` copy shape: "Sign-in unavailable: token
verification not wired."). Failing before the browser, not
after the callback, is the honest place: the user must never
complete an EVE consent flow whose token Mimir then refuses
for a purely local wiring reason it knew beforehand.

### 8.4 What does not move

`parse_jwt_claims` stays public (`src/auth/mod.rs:11`
re-export) for parser unit tests, with its doc comment amended
by Builder A to begin `UNVERIFIED decode … production trust
decisions must use JwtVerifier::verify`. The integrator's grep
(Section 11) is the enforcement that no production caller
remains. `validate_expected_character`, scope helpers, PKCE,
callback server, and `TokenStore` storage internals are
unchanged.

## 9. Test plan — zero live network (Decision J7)

Repository gates for every builder (from
`.github/workflows/ci.yml`, Analyze + Test jobs):
`cargo fmt --check`, `cargo clippy --all-targets -- -D warnings`,
`cargo test`. No test contacts `login.eveonline.com` or any
non-loopback host.

### Test keys: generated in code, dev-dependencies justified

Verifying real signatures needs real key pairs. **No PEM files
and no embedded private-key constants are committed** — fixture
keys are generated at test time inside `#[cfg(test)]` code, so
nothing key-like ever sits in the repository. That requires
key-generation + signing primitives in tests, which
`jsonwebtoken` does not provide (it encodes given a key; it
does not mint keys). Builder A therefore adds two
**dev-only** dependencies:

```toml
[dev-dependencies]
rsa = "<same major as pulled by jsonwebtoken/rust_crypto>"
p256 = { version = "<same major>", features = ["ecdsa"] }
```

Justification (the only dev-dependency growth in this slice):
(a) both are already transitive dependencies of the selected
runtime stack, so the build graph grows by zero new *crates*,
only by two direct dev edges pinned to the already-present
majors (Builder A proves this with `cargo tree` before/after);
(b) they exist solely to *sign* fixture tokens independently
of the code under test (below); (c) they can never appear in a
release artifact. `tempfile` remains the only other
dev-dependency (`Cargo.toml:30-31`).

**Fixture tokens are signed manually, not with the library's
encoder.** The test helper (in `jwt_verify.rs` tests, marked
obviously test-only) builds `base64url(header).base64url(payload)`
with the existing `base64` crate, signs the ASCII signing
input directly — RSA PKCS#1 v1.5 with SHA-256 via the `rsa`
dev crate for RS256, ECDSA P-256 via the `p256` dev crate with
the signature serialized as raw `r‖s` for ES256 — and appends
the base64url signature. It likewise derives the JWKS document
(`n`/`e`, `x`/`y` components, chosen `kid`s) from the generated
public keys. This matters: signing and verifying with the same
library would make the happy-path tests prove only roundtrip
self-consistency. Here a passing verify means the library
accepted an independently produced JWS, and the negative cases
can falsify real checks. A 2048-bit RSA key generation takes
on the order of a second; helpers generate one RSA key and one
P-256 key per test that needs them (no shared mutable fixture,
no `LazyLock` key ceremony). If suite time becomes a problem
that is a test-helper refactor, never a reason to commit key
material.

### Mock JWKS server: existing loopback style, extended

`jwt_verify.rs` tests copy the one-shot pattern from
`src/esi/client.rs:346-368` (bind `127.0.0.1:0`, read one
request, write one HTTP/1.1 response) and extend it to a
*sequence* server: it serves the Nth queued response body to
the Nth accepted connection and counts hits in an
`Arc<AtomicUsize>`, because the unknown-`kid` cases must prove
*exactly one* refetch (Section 6), which a one-shot server
cannot observe. The JWKS JSON it serves is the string built
from the generated test keys — never a captured real-world
JWKS.

### Cases (Builder A, `jwt_verify.rs` tests unless noted)

Pure core (`verify_with_keys`, no HTTP at all):

1. **Valid RS256** — Ok; returned `JwtClaims` matches the
   signed payload (`character_id()`, `scp`, `exp`, `name`).
2. **Valid ES256** — Ok, same assertions (ES256 is supported
   by the selected dependency, Section 4; this case is
   mandatory, not optional, so EVE's future switch needs no
   code change).
3. **Expired** (`exp` in the past beyond leeway, and one at
   the leeway boundary on each side) →
   `InvalidClaims("expired")`.
4. **Wrong issuer** (other host; `http://` spelling; missing)
   → `InvalidClaims("issuer")`. Both accepted spellings pass
   (fold into cases 1–2).
5. **Wrong audience** — missing client id; missing
   `"EVE Online"`; client id smuggled as `azp` only;
   string-form `aud` equal to the client id alone (must fail:
   `"EVE Online"` absent) → `InvalidClaims("audience")`.
6. **Missing `exp`** and `exp: 0` → `InvalidClaims("missing_exp")`;
   **future `nbf`** → `InvalidClaims("not_yet_valid")`; **`nbf`
   in the past** → Ok (fold into case 1 variant).
7. **Algorithm `none`** (empty signature segment) →
   `InvalidSignature` (or `MalformedToken` only if header
   parsing itself rejects it — Builder A records which the
   pinned library yields and asserts exactly that; it must be
   one of the two, never Ok).
8. **Algorithm mismatch** — ES256 header + RSA key; RS256
   header + EC key; HS256 header with an HMAC forged over the
   public components → `InvalidSignature` each.
9. **Tampered payload** — sign, then re-encode a payload with
   a different `sub` under the original signature →
   `InvalidSignature`. **Wrong-key signature** (signed by a
   second generated RSA key, JWKS carries the first) →
   `InvalidSignature`.
10. **Malformed** — `not-a-jwt`, two segments, bad base64,
    header without `kid`, empty `kid`, non-JSON payload →
    `MalformedToken`. (Mirrors existing expectations at
    `src/auth/oauth.rs:584-589`, which keep passing for the
    parser itself.)
11. **Unknown `kid`** in the pure core → `UnknownSigningKey`;
    **duplicate `kid`** in the key set → `UnknownSigningKey`;
    **unusable keys** (`oct`, P-384 `crv`, `use: "enc"`, JWK
    `alg` disagreeing with `kty`, missing components) are
    excluded at JWKS parse (parse-level unit test on the
    private model: usable count + which `kid`s survive).

Async wrapper (`JwtVerifier::verify` + mock JWKS server):

12. **Unknown `kid`, then refetch success** — first JWKS
    response lacks the token's `kid`, second includes it → Ok,
    and the server hit count is **exactly 2**.
13. **Unknown `kid` even after refetch** → `UnknownSigningKey`,
    hit count exactly 2 (proves no refetch loop).
14. **Cache reuse** — two verifies, same `kid`, fresh TTL →
    hit count stays 1.
15. **Expired cache + failed refetch fails closed** — TTL
    override `Duration::ZERO` (Section 6), first verify Ok,
    then the server starts returning 500 → second verify →
    `JwksUnavailable` even though the `kid` was cached.
16. **JWKS errors** — non-2xx, unparseable JSON, `{"keys":[]}`,
    all-keys-unusable → `JwksUnavailable` each. `Cache-Control:
    max-age` is honoured-capped: a max-age above 3600 yields
    ttl 3600 (assert the cache state, not a sleep).
17. **`expiry_for_verified` + `deserialize_aud`** (in
    `oauth.rs` tests, Builder A): verified `exp` wins;
    `exp`-absent fallback arithmetic unchanged
    (`expires_at_unix` behaviour at
    `src/auth/oauth.rs:749` stays green); `aud` string →
    one-element vec, array → vec, number → empty vec.

Builder B test obligations (wiring):

18. **Update** `auth_get_refreshes_expired_token_via_mock`
    (`src/esi/client.rs:419-457`): its mock token endpoint
    currently returns a non-JWT placeholder string
    (`:424`), which must now be rejected. The token endpoint
    mock returns a properly test-signed RS256 token (reusing
    Builder A's signing helper — Builder B may move/copy the
    helper into a `#[cfg(test)]` module visible to both test
    mods, and says where it lives), the client gets a
    `JwtVerifier::with_endpoint` pointed at a mock JWKS server
    via `with_jwt_verifier`, and the existing assertions
    (refresh hit, Bearer used, rotated tokens persisted) keep
    their meaning — the persisted-access equality now compares
    against the signed token value the mock returned.
19. **Refresh rejects unverifiable token, saves nothing** —
    same harness, token endpoint returns a tampered/garbage
    access token → `auth_get` errors, and `store.load(99)`
    still shows the *original* seeded tokens (the regression
    test for the whole fail-closed purpose at T4).
20. **Refresh rejects wrong character** — validly signed token
    whose `sub` names a different character → error, stored
    tokens unchanged.
21. All pre-existing tests pass unmodified in expectation,
    including `jwt_claims_parse_character_and_scopes`,
    `malformed_jwt_is_rejected`,
    `validate_expected_character_match_mismatch_and_malformed`
    (parser-level, still meaningful), the scope-union/step-up
    tests, `token_store` tests (updated only for the
    `from_token_response`/`apply_refresh` signature change,
    `src/auth/token_store.rs:394-407`), and both `config.rs`
    scope guard tests.

`src/app/shell.rs` still has no test module and this slice
adds none (same constraint the step-up design recorded,
`docs/stepup-oauth-design.md:576-585`): T1/T2 wiring differs
from the old code by exactly the verified call, whose entire
behaviour is covered above; the integrator's live matrix
(Section 11) covers the shell end-to-end.

## 10. Security and logging rules (all builders)

- **Never log or display:** access/refresh token values, any
  token segment (header, payload, or signature) in raw or
  decoded form, full token-endpoint responses, authorization
  codes, CSRF state, PKCE verifiers, full authorize URLs
  (existing rules), or private key material of any kind. Test
  private keys exist only as generated values inside
  `#[cfg(test)]` functions — never in files, constants, test
  output, or assertion messages (assert with variant matches,
  `expect("…")` strings name cases, not values; existing
  precedent `src/auth/oauth.rs:726`: "Never print the URL").
- **May be logged:** public `kid` strings, algorithm names,
  issuer *category* (`host`/`uri`), the closed
  `InvalidClaims` categories, scope names, character ids,
  key counts, JWKS fetch status, cache hit/refetch decisions.
  Even though JWK components are public keys, they are not
  logged (Section 8.1): the rule "keys never appear in logs"
  stays absolute and auditable by grep.
- Every new log line uses `tracing` with the `[AUTH]` bracket
  tag (`[ESI]` only where the line is about an ESI request as
  such; the T4 verify lines inside `valid_access_token` are
  `[AUTH]`, matching its existing refresh log at
  `src/esi/client.rs:182-185`). No `println!`, no `{:?}` of
  `TokenResponse`/claims-bearing values that could carry
  token strings (the existing redacted `Debug` impls stay the
  safety net, not an invitation).
- Verification is the *only* new network call, to the
  Section 3 JWKS URL over rustls; nothing about tokens is sent
  to it (a JWKS GET carries no token — tests assert the mock
  JWKS server received no `Authorization` header, mirroring
  `src/esi/client.rs:394`).

## 11. Ownership, sequencing, integrator gates

Strictly sequential in the shared tree on
`feat/jwt-signature-verification`: Builder A finishes and
commits, then Builder B, then the integrator. Nobody edits
the other builder's files; an insufficient shape is reported
back. No attribution lines in any commit.

| Owner | Files (complete list) | Contents |
|---|---|---|
| Design (this commit) | `docs/jwt-verification-design.md` only | This document. Commit: `docs: design JWT signature verification` |
| **Builder A** — dependency + verification module + pure tests | `Cargo.toml`, `Cargo.lock` (generated), `src/config.rs`, `src/error.rs`, `src/auth/jwt_verify.rs` (new), `src/auth/mod.rs`, `src/auth/oauth.rs` (claims-shape edits only) | `jsonwebtoken` (`rust_crypto`) as the one runtime dependency + justified `rsa`/`p256` dev-dependencies (J2/J7, exact versions in commit body); `OAUTH_METADATA_URL`/`OAUTH_JWKS_URL` constants + a test asserting both are on `OAUTH_HOST` (J1); the four `AuthError` variants (J5); `JwtClaims.aud`/`nbf` + `deserialize_aud` + `expiry_for_verified` + `parse_jwt_claims` UNVERIFIED doc amendment + `default_http` visibility if reused (J3/J6); the whole verifier module — JWK model, `verify_with_keys`, cache, `JwtVerifier` (J3/J4/J6); test cases 1–17. Suggested commit: `feat(auth): add JWT signature verification module` |
| **Builder B** — shell/client wiring at the trust points | `src/app/shell.rs`, `src/esi/client.rs`, `src/auth/token_store.rs`, `src/main.rs` | T1/T2 verified calls + verifier-absence pre-browser failure (8.2/8.3); `Backends.jwt_verifier` + one shared instance in `main.rs`; `StoredTokens::from_token_response`/`apply_refresh` take verified claims (8.2); `EsiClient::with_jwt_verifier` + T4 verify-then-character-check-then-save + absence rule; test cases 18–21. Suggested commit: `feat(auth): verify tokens at login, step-up, and refresh` |
| **Integrator** | `docs/rust-rewrite-design.md` (the named-gap line), `docs/engineering-journal/LEARNINGS.md` or `DECISIONS.md`, `README.md` **only if** it states tokens are unverified | Final gates + audits + live matrix below; updates the follow-up wording that named this gap (`docs/rust-rewrite-design.md:277-278`, `docs/stepup-oauth-design.md:489-493` is a design record and is *not* rewritten). Suggested commit: `docs: record JWT verification landing` |

Hard overlaps to respect: Builder B does not touch
`jwt_verify.rs`, `error.rs`, or `config.rs` — a missing
variant/constant/helper is reported to Builder A, not added.
Builder A does not touch `shell.rs`, `client.rs`,
`token_store.rs`, or `main.rs`; `expiry_for` may keep zero-to-
some callers during A's commit solely so the tree compiles
green between builders (B removes its production callers).

### Integrator gates

1. `cargo fmt --check`,
   `cargo clippy --all-targets -- -D warnings`, `cargo test`
   — record exact outputs/test counts.
2. **No OpenSSL proof:** `cargo tree | grep -i openssl` is
   empty; `cargo tree -i rsa` / `-i p256` show they arrive via
   `jsonwebtoken` at the majors the dev-dependencies pin.
3. **Residual-trust grep:** `grep -rn parse_jwt_claims src/`
   outside `#[cfg(test)]` shows only its definition (+ the
   UNVERIFIED doc) and — if Builder B kept it — the recorded
   fate of `expiry_for` with zero production callers. Every
   `token_store.save` / `set_token_meta` call site is preceded
   in its function by a `verify` on the same token (manual
   read of the three sites, T1/T2/T4).
4. **Scope audits:** diff shows `FIRST_AUTH_SCOPES` contents
   untouched (`src/config.rs:26-32`), no file under
   `src/storage/`, no schema/migration change, no new file
   under `src/` except `src/auth/jwt_verify.rs`, exactly one
   added `[dependencies]` line.
5. **Secret audit:** grep the diff for logging/format of
   `access_token`, `refresh`, token segments, JWKS bodies,
   and any PEM block (`BEGIN .* KEY` must appear nowhere,
   including tests).
6. **Live manual matrix** (real EVE account): fresh sign-in
   succeeds and Skills/Wallet refresh; step-up from Assets
   succeeds as the same character; restart with an expired
   access token refreshes silently (T4 through the real
   JWKS); logs show `[AUTH]` verify-ok lines with the public
   `kid` and zero token material. Offline run (network off):
   cached data still renders, refresh fails with a
   `Refresh failed:` status and previously saved characters
   remain usable on next online launch. Record results;
   negative live cases (forged token) are unit-covered, not
   attempted against EVE.

## 12. Explicit non-goals and accepted limits

- **Widening first authorization.** `FIRST_AUTH_SCOPES`
  contents, `first_auth_scopes_string()`, and both config
  guard tests are untouched.
- **Database schema migration.** None. `token_meta` shape and
  `src/storage/` are untouched; JWKS state is memory-only.
- **New feature modules or UI views.** None. The only new file
  under `src/` is the auth-internal `src/auth/jwt_verify.rs`;
  user-visible behaviour changes only in that bad tokens now
  fail sign-in/refresh with existing message paths.
- **More than one runtime dependency / OpenSSL.** J2 is the
  whole dependency story; `aws_lc_rs` backend is not enabled.
- **Runtime SSO metadata discovery.** Recorded, not fetched
  (J1). Adding it later must keep the same host allowlist.
- **Re-verifying stored tokens at load or per ESI call.**
  Verification gates *receipt* (T1/T2/T4). Tokens saved before
  this slice are used until their next refresh, which then
  verifies (T6/T7 bounded reasoning).
- **Token revocation / `owner` (character-transfer) checks,
  `jti` replay tracking, key pinning.** None of these drive a
  Mimir decision today; each is its own follow-up if ever
  needed. TLS to the JWKS host is the root of trust for the
  key set, as it already is for the token endpoint.
- **Pushing or merging.** Branch work ends at local commits.

Accepted limits, stated honestly: a JWKS outage blocks new
sign-ins and refreshes while it lasts (fail closed, Section 1);
the 60-second leeway and the 3600-second maximum cache TTL are
judgement calls recorded in J3/J4, revisitable with evidence;
ES256 support is tested against locally generated keys because
EVE does not issue ES256 tokens yet, so the first real ES256
token remains an (expected-uneventful) live event for the
integrator's successors to notice in logs via the public
algorithm field.




