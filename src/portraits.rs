//! Character portraits, corporation logos, alliance logos, and
//! faction logos: unauthenticated fetch from the EVE image service,
//! on-disk caching under the app cache directory, and bounded decode.
//! All four kinds share one pipeline keyed by `(ImageKind, id)` with
//! one semaphore; they are public, so this layer never fetches or
//! attaches a token. Every public function logs with the
//! `[PORTRAIT]` tag; ids are logged as plain integers (the
//! `[CHAR]`/`[ESI]` convention). URLs, tokens, entity names, and
//! error bodies never appear in logs.

use std::path::{Path, PathBuf};
use std::sync::Arc;

use tokio::sync::Semaphore;

use crate::config::EveConfig;

/// Which kind of image one pipeline key names. The kind is part of
/// every key: the same number in two kinds is two different
/// entities (a corporation and a character can share an id), so
/// one kind's bytes must never serve another kind's slot.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum ImageKind {
    Character,
    Corporation,
    Alliance,
    Faction,
}

impl ImageKind {
    /// Fixed lower-case word for log lines: "character",
    /// "corporation", "alliance", or "faction". Never derived from
    /// user text.
    pub fn as_str(&self) -> &'static str {
        match self {
            ImageKind::Character => "character",
            ImageKind::Corporation => "corporation",
            ImageKind::Alliance => "alliance",
            ImageKind::Faction => "faction",
        }
    }
}

/// The one portrait size the whole app requests. Renders downscale
/// it; nothing upscales past what was decoded.
pub const PORTRAIT_SIZE: u32 = 256;
/// The one logo size the whole app requests (corporation, alliance,
/// and faction). 512 would exceed `MAX_IMAGE_BYTES` on dense logos,
/// so the fixed logo size stays small and renders downscale it.
pub const LOGO_SIZE: u32 = 64;
/// Maximum accepted portrait body (1 MiB). The streamed download
/// aborts above this and decode rejects bodies above it. Decode
/// itself is bounded by explicit image-crate limits (dimensions
/// and allocation), so a small body cannot expand unchecked.
pub const MAX_IMAGE_BYTES: usize = 1 << 20;
/// Maximum accepted decoded width or height. A body that decodes
/// beyond this is rejected, never shown.
pub const MAX_IMAGE_DIMENSION: u32 = 1024;
/// Maximum portraits and logos in flight app-wide. The shell spawns
/// one task per requested key; this one semaphore bounds every kind
/// together.
pub const MAX_CONCURRENT_FETCHES: usize = 4;

/// Portrait fetch/cache/decode failure. Display text is fixed words
/// plus a status code or IO/decode error string; it never embeds a
/// URL, a token, or user text, and it is log-only (views fall back
/// to the initial placeholder and never render it).
#[derive(Debug, thiserror::Error)]
pub enum PortraitError {
    #[error("[PORTRAIT] http error: {0}")]
    Http(String),
    #[error("[PORTRAIT] portrait request failed with status {0}")]
    Status(u16),
    #[error("[PORTRAIT] portrait exceeds the size limit")]
    TooLarge,
    #[error("[PORTRAIT] portrait decode failed: {0}")]
    Decode(String),
    #[error("[PORTRAIT] portrait cache error: {0}")]
    CacheIo(String),
}

/// Cache file name for one kind-keyed image: the character row is
/// the shipped legacy `{id}_{size}.jpg`, corporation is
/// `corp-{id}_{size}.png`, alliance is `alliance-{id}_{size}.png`,
/// faction is `faction-{id}_{size}.png`. The kind prefix is
/// load-bearing: one number in two kinds must never share a file,
/// and extensions follow the observed service content types (JPEG
/// portraits, PNG logos).
pub fn cache_filename(kind: ImageKind, id: i64, size: u32) -> String {
    match kind {
        ImageKind::Character => format!("{id}_{size}.jpg"),
        ImageKind::Corporation => format!("corp-{id}_{size}.png"),
        ImageKind::Alliance => format!("alliance-{id}_{size}.png"),
        ImageKind::Faction => format!("faction-{id}_{size}.png"),
    }
}

/// Full path of one cached image under the portraits directory
/// (`{app_cache_dir}/portraits/`, never the database).
pub fn cache_path(portrait_dir: &Path, kind: ImageKind, id: i64, size: u32) -> PathBuf {
    portrait_dir.join(cache_filename(kind, id, size))
}

/// Placeholder initial for one character name: the first alphabetic
/// character, ASCII-uppercased, or `None` when the name has none.
/// Pure so the view's honest placeholder (never a fabricated face)
/// is table-testable.
pub fn initial_for_name(name: &str) -> Option<char> {
    name.chars()
        .find(|c| c.is_alphabetic())
        .map(|c| c.to_ascii_uppercase())
}

/// Decode image bytes within the byte and dimension caps.
/// Anything above a cap, or anything that is not a decodable image,
/// is an error: the caller shows the placeholder, never a guess.
/// This decodes character portraits and corporation/alliance/faction
/// logos alike (JPEG portraits, PNG logos).
pub fn decode_portrait(bytes: &[u8]) -> Result<image::DynamicImage, PortraitError> {
    tracing::debug!("[PORTRAIT] decoding portrait bytes={}", bytes.len());
    if bytes.len() > MAX_IMAGE_BYTES {
        return Err(PortraitError::TooLarge);
    }
    if bytes.is_empty() {
        return Err(PortraitError::Decode("empty portrait body".to_string()));
    }
    // Bound the decode itself, not just its result: a tiny body
    // can expand to a huge allocation, so the dimension and
    // allocation caps must apply inside the decoder.
    let mut limits = image::Limits::default();
    limits.max_image_width = Some(MAX_IMAGE_DIMENSION);
    limits.max_image_height = Some(MAX_IMAGE_DIMENSION);
    // 1024x1024 RGBA is 4 MiB; allow decoder scratch above that.
    limits.max_alloc = Some(32 << 20);
    let mut reader = image::ImageReader::new(std::io::Cursor::new(bytes))
        .with_guessed_format()
        .map_err(|e| PortraitError::Decode(e.to_string()))?;
    reader.limits(limits);
    let decoded = match reader.decode() {
        Ok(d) => d,
        Err(image::ImageError::Limits(_)) => return Err(PortraitError::TooLarge),
        Err(e) => return Err(PortraitError::Decode(e.to_string())),
    };
    if decoded.width() > MAX_IMAGE_DIMENSION || decoded.height() > MAX_IMAGE_DIMENSION {
        return Err(PortraitError::TooLarge);
    }
    tracing::debug!(
        "[PORTRAIT] decoded portrait {}x{}",
        decoded.width(),
        decoded.height()
    );
    Ok(decoded)
}

/// Unauthenticated portrait downloader. The base URL is injectable
/// (mirroring `EsiClient::with_base_url`) so tests can point it at
/// a local mock server; construction performs no network I/O.
pub struct PortraitClient {
    http: reqwest::Client,
    image_base_url: String,
}

impl Default for PortraitClient {
    fn default() -> Self {
        Self::new()
    }
}

impl PortraitClient {
    pub fn new() -> Self {
        Self::with_base_url(EveConfig::IMAGE_SERVER_URL.to_string())
    }

    pub fn with_base_url(image_base_url: String) -> Self {
        tracing::info!("[PORTRAIT] creating portrait client");
        // Timeout and User-Agent are the only builder settings, and
        // both are infallible in practice; the fallback keeps
        // construction total so the caller never fails on it.
        let http = reqwest::Client::builder()
            .timeout(std::time::Duration::from_millis(
                EveConfig::DEFAULT_TIMEOUT_MS,
            ))
            .user_agent(EveConfig::USER_AGENT)
            .build()
            .unwrap_or_else(|_| reqwest::Client::new());
        Self {
            http,
            image_base_url: image_base_url.trim_end_matches('/').to_string(),
        }
    }

    /// Fetch one image body (any kind), aborting the download as soon as it exceeds `MAX_IMAGE_BYTES`.
    /// Non-success statuses map to
    /// `PortraitError::Status`; the URL never appears in logs.
    pub async fn fetch_bytes(
        &self,
        kind: ImageKind,
        id: i64,
        size: u32,
    ) -> Result<Vec<u8>, PortraitError> {
        tracing::info!(
            "[PORTRAIT] fetching image kind={} id={} size={}",
            kind.as_str(),
            id,
            size
        );
        // Production goes through the one named URL seam so the
        // host/path cannot drift; only the test seam (injected
        // base) formats against its own base.
        let url = if self.image_base_url == EveConfig::IMAGE_SERVER_URL {
            match kind {
                ImageKind::Character => EveConfig::portrait_url(id, size),
                ImageKind::Corporation => EveConfig::corporation_logo_url(id, size),
                ImageKind::Alliance => EveConfig::alliance_logo_url(id, size),
                ImageKind::Faction => EveConfig::faction_logo_url(id, size),
            }
        } else {
            match kind {
                ImageKind::Character => format!(
                    "{}/characters/{}/portrait?size={}",
                    self.image_base_url, id, size
                ),
                ImageKind::Corporation => {
                    format!(
                        "{}/corporations/{}/logo?size={}",
                        self.image_base_url, id, size
                    )
                }
                ImageKind::Alliance => {
                    format!(
                        "{}/alliances/{}/logo?size={}",
                        self.image_base_url, id, size
                    )
                }
                ImageKind::Faction => {
                    format!(
                        "{}/corporations/{}/logo?size={}",
                        self.image_base_url, id, size
                    )
                }
            }
        };
        let mut response = self
            .http
            .get(&url)
            .send()
            .await
            .map_err(|e| PortraitError::Http(e.without_url().to_string()))?;
        if !response.status().is_success() {
            return Err(PortraitError::Status(response.status().as_u16()));
        }
        let mut bytes = Vec::new();
        while let Some(chunk) = response
            .chunk()
            .await
            .map_err(|e| PortraitError::Http(e.without_url().to_string()))?
        {
            if bytes.len() + chunk.len() > MAX_IMAGE_BYTES {
                return Err(PortraitError::TooLarge);
            }
            bytes.extend_from_slice(&chunk);
        }
        if bytes.is_empty() {
            return Err(PortraitError::Decode("empty portrait body".to_string()));
        }
        tracing::debug!(
            "[PORTRAIT] fetched image kind={} id={} bytes={}",
            kind.as_str(),
            id,
            bytes.len()
        );
        Ok(bytes)
    }
}

/// On-disk image cache (all four kinds) rooted at
/// `{app_cache_dir}/portraits/`. All IO here is local filesystem,
/// never network. Growth is bounded in practice by the user's own
/// characters (one small JPEG per character, one small PNG per
/// corporation/alliance/faction at the fixed sizes); entries for removed
/// characters are left on disk deliberately — they are inert,
/// keyed by kind and id, and reused if the character returns.
pub struct PortraitStore {
    dir: PathBuf,
}

impl PortraitStore {
    /// `cache_dir` is the app cache directory itself
    /// (`crate::storage::db::app_cache_dir` in the app); the
    /// `portraits` subdirectory is added here.
    pub fn new(cache_dir: PathBuf) -> Self {
        let dir = cache_dir.join("portraits");
        tracing::debug!("[PORTRAIT] portrait store opened");
        Self { dir }
    }

    /// Cached body for one kind-keyed image, or `None` on a miss or
    /// unreadable file. A miss is silent on purpose: the caller
    /// refetches.
    pub fn read_cached(&self, kind: ImageKind, id: i64, size: u32) -> Option<Vec<u8>> {
        let path = cache_path(&self.dir, kind, id, size);
        // Bounded read: never load more than the decode cap, so a
        // stray oversized file cannot fill memory before checks.
        use std::io::Read as _;
        let file = std::fs::File::open(&path).ok()?;
        let mut bytes = Vec::new();
        file.take((MAX_IMAGE_BYTES + 1) as u64)
            .read_to_end(&mut bytes)
            .ok()?;
        tracing::debug!(
            "[PORTRAIT] cache hit kind={} id={} bytes={}",
            kind.as_str(),
            id,
            bytes.len()
        );
        Some(bytes)
    }

    /// Write one body atomically: temp file in the same directory,
    /// then rename, so a torn write never poisons the next read.
    pub fn write_cached(
        &self,
        kind: ImageKind,
        id: i64,
        size: u32,
        bytes: &[u8],
    ) -> Result<(), PortraitError> {
        std::fs::create_dir_all(&self.dir).map_err(|e| PortraitError::CacheIo(e.to_string()))?;
        let path = cache_path(&self.dir, kind, id, size);
        let tmp = self.dir.join(format!(
            "{}.tmp{}",
            cache_filename(kind, id, size),
            rand::random::<u64>()
        ));
        std::fs::write(&tmp, bytes).map_err(|e| PortraitError::CacheIo(e.to_string()))?;
        if let Err(e) = std::fs::rename(&tmp, &path) {
            let _ = std::fs::remove_file(&tmp);
            return Err(PortraitError::CacheIo(e.to_string()));
        }
        tracing::debug!(
            "[PORTRAIT] cache write kind={} id={} bytes={}",
            kind.as_str(),
            id,
            bytes.len()
        );
        Ok(())
    }

    /// Drop one entry (a poisoned cache file that failed decode).
    /// Best-effort: the entry is already known unreadable.
    pub fn remove_cached(&self, kind: ImageKind, id: i64, size: u32) {
        let path = cache_path(&self.dir, kind, id, size);
        let _ = std::fs::remove_file(&path);
        tracing::debug!(
            "[PORTRAIT] cache entry removed kind={} id={}",
            kind.as_str(),
            id
        );
    }
}

/// App-wide image service (all four kinds): client + store + the
/// one semaphore that bounds in-flight portraits and logos
/// together.
pub struct PortraitService {
    client: PortraitClient,
    store: PortraitStore,
    semaphore: Arc<Semaphore>,
}

impl PortraitService {
    /// Production constructor: default image-service client and the
    /// app cache directory. Performs no network or disk I/O.
    pub fn new(cache_dir: PathBuf) -> Self {
        Self::with_client(PortraitClient::new(), cache_dir)
    }

    /// Test-seam constructor with an injected client (mock base URL).
    pub fn with_client(client: PortraitClient, cache_dir: PathBuf) -> Self {
        tracing::info!("[PORTRAIT] portrait service constructed");
        Self {
            client,
            store: PortraitStore::new(cache_dir),
            semaphore: Arc::new(Semaphore::new(MAX_CONCURRENT_FETCHES)),
        }
    }

    /// One kind-keyed image, cache-first: a cache hit decodes and
    /// returns with zero network calls; a miss fetches (under the
    /// semaphore, so at most `MAX_CONCURRENT_FETCHES` are ever in
    /// flight), writes the cache best-effort, and decodes. A cached
    /// body that fails decode is a miss (the entry is dropped and
    /// refetched once).
    pub async fn image(
        &self,
        kind: ImageKind,
        id: i64,
        size: u32,
    ) -> Result<Arc<image::DynamicImage>, PortraitError> {
        tracing::info!(
            "[PORTRAIT] image requested kind={} id={} size={}",
            kind.as_str(),
            id,
            size
        );
        // The semaphore outlives every task that holds a permit, so
        // acquire cannot fail; a closed gate is a bug, not input.
        let _permit = self
            .semaphore
            .clone()
            .acquire_owned()
            .await
            .expect("image semaphore is app-lifetime, never closed");
        if let Some(bytes) = self.store.read_cached(kind, id, size) {
            match decode_portrait(&bytes) {
                Ok(image) => return Ok(Arc::new(image)),
                Err(e) => {
                    tracing::warn!(
                        "[PORTRAIT] poisoned cache entry dropped kind={} id={} error={}",
                        kind.as_str(),
                        id,
                        e
                    );
                    self.store.remove_cached(kind, id, size);
                }
            }
        }
        let bytes = self.client.fetch_bytes(kind, id, size).await?;
        // Validate before caching: a non-image 200 body must never
        // persist and re-poison later launches.
        let image = decode_portrait(&bytes)?;
        // The cache is an optimization: a failed write is logged and
        // the fetched image still shows.
        if let Err(e) = self.store.write_cached(kind, id, size, &bytes) {
            tracing::warn!(
                "[PORTRAIT] cache write failed kind={} id={} error={}",
                kind.as_str(),
                id,
                e
            );
        }
        tracing::info!(
            "[PORTRAIT] image ready kind={} id={} size={}",
            kind.as_str(),
            id,
            size
        );
        Ok(Arc::new(image))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tokio::io::{AsyncReadExt, AsyncWriteExt};
    use tokio::net::TcpListener;

    /// One-shot HTTP test server: captures the request line, returns
    /// `body` verbatim with `status` (mirrors the EsiClient mock).
    async fn mock_bytes_server(
        status: u16,
        body: Vec<u8>,
    ) -> (String, tokio::sync::oneshot::Receiver<String>) {
        let listener = TcpListener::bind("127.0.0.1:0").await.expect("bind mock");
        let addr = listener.local_addr().expect("addr");
        let (tx, rx) = tokio::sync::oneshot::channel::<String>();
        tokio::spawn(async move {
            if let Ok((mut socket, _peer)) = listener.accept().await {
                let mut buffer = vec![0u8; 16384];
                let count = socket.read(&mut buffer).await.unwrap_or(0);
                let _ = tx.send(String::from_utf8_lossy(&buffer[..count]).into_owned());
                let head = format!(
                    "HTTP/1.1 {status} OK\r\nContent-Type: image/png\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",
                    body.len()
                );
                let _ = socket.write_all(head.as_bytes()).await;
                let _ = socket.write_all(&body).await;
                let _ = socket.flush().await;
            }
        });
        (format!("http://{addr}"), rx)
    }

    /// A real decodable PNG of exactly `width` x `height`, generated
    /// in code (no committed image fixture).
    fn generated_png(width: u32, height: u32) -> Vec<u8> {
        let img = image::DynamicImage::ImageRgb8(image::RgbImage::new(width, height));
        let mut bytes = Vec::new();
        img.write_to(
            &mut std::io::Cursor::new(&mut bytes),
            image::ImageFormat::Png,
        )
        .expect("encode png");
        bytes
    }

    /// A real decodable RGBA PNG whose pixels are exactly the given
    /// literals, in row-major order, so alpha is assertable. The
    /// opaque helper above cannot express alpha.
    fn generated_rgba_png(pixels: &[[u8; 4]]) -> Vec<u8> {
        let mut img = image::RgbaImage::new(pixels.len() as u32, 1);
        for (x, pixel) in pixels.iter().enumerate() {
            img.put_pixel(x as u32, 0, image::Rgba(*pixel));
        }
        let mut bytes = Vec::new();
        image::DynamicImage::ImageRgba8(img)
            .write_to(
                &mut std::io::Cursor::new(&mut bytes),
                image::ImageFormat::Png,
            )
            .expect("encode rgba png");
        bytes
    }

    #[test]
    fn cache_naming_is_character_keyed() {
        assert_eq!(
            cache_filename(ImageKind::Character, 90000001, 256),
            "90000001_256.jpg"
        );
        assert_eq!(
            cache_filename(ImageKind::Corporation, 1000166, 64),
            "corp-1000166_64.png"
        );
        assert_eq!(
            cache_filename(ImageKind::Alliance, 99003581, 64),
            "alliance-99003581_64.png"
        );
        assert_eq!(
            cache_filename(ImageKind::Faction, 500001, 64),
            "faction-500001_64.png"
        );
        assert_eq!(ImageKind::Character.as_str(), "character");
        assert_eq!(ImageKind::Corporation.as_str(), "corporation");
        assert_eq!(ImageKind::Alliance.as_str(), "alliance");
        assert_eq!(ImageKind::Faction.as_str(), "faction");
        // The same number in four kinds names four distinct files:
        // one kind's bytes can never serve another kind's slot.
        let character = cache_filename(ImageKind::Character, 1000166, 64);
        let corporation = cache_filename(ImageKind::Corporation, 1000166, 64);
        let alliance = cache_filename(ImageKind::Alliance, 1000166, 64);
        let faction = cache_filename(ImageKind::Faction, 1000166, 64);
        let names = [&character, &corporation, &alliance, &faction];
        for i in 0..names.len() {
            for j in (i + 1)..names.len() {
                assert_ne!(names[i], names[j], "names {i} and {j} must differ");
            }
        }
        let dir = std::path::Path::new("/tmp/example-cache/portraits");
        assert_eq!(
            cache_path(dir, ImageKind::Character, 90000001, 256),
            std::path::Path::new("/tmp/example-cache/portraits/90000001_256.jpg")
        );
        assert_eq!(
            cache_path(dir, ImageKind::Corporation, 1000166, 64),
            std::path::Path::new("/tmp/example-cache/portraits/corp-1000166_64.png")
        );
    }

    #[test]
    fn placeholder_initials_cover_the_shape() {
        assert_eq!(initial_for_name("Dread Pirate Roberts"), Some('D'));
        assert_eq!(initial_for_name("  xana"), Some('X'));
        assert_eq!(initial_for_name(""), None);
        assert_eq!(initial_for_name("123"), None);
    }

    #[test]
    fn decode_accepts_a_real_jpeg_body() {
        // The live service sends JPEG; fixtures elsewhere are PNG.
        let img = image::DynamicImage::ImageRgb8(image::RgbImage::new(4, 4));
        let mut bytes = Vec::new();
        img.write_to(
            &mut std::io::Cursor::new(&mut bytes),
            image::ImageFormat::Jpeg,
        )
        .expect("encode jpeg");
        let decoded = decode_portrait(&bytes).expect("jpeg decodes");
        assert_eq!((decoded.width(), decoded.height()), (4, 4));
    }

    #[test]
    fn decode_round_trips_dimensions() {
        let bytes = generated_png(4, 3);
        let decoded = decode_portrait(&bytes).expect("generated png decodes");
        assert_eq!(decoded.width(), 4);
        assert_eq!(decoded.height(), 3);
    }

    #[test]
    fn decode_rejects_garbage_empty_and_oversized_bodies() {
        assert!(matches!(
            decode_portrait(b"not an image"),
            Err(PortraitError::Decode(_))
        ));
        assert!(matches!(
            decode_portrait(&[]),
            Err(PortraitError::Decode(_))
        ));
        let over_cap = vec![0u8; MAX_IMAGE_BYTES + 1];
        assert!(matches!(
            decode_portrait(&over_cap),
            Err(PortraitError::TooLarge)
        ));
    }

    #[test]
    fn decode_rejects_dimensions_beyond_the_cap() {
        let wide = generated_png(MAX_IMAGE_DIMENSION + 1, 2);
        assert!(matches!(
            decode_portrait(&wide),
            Err(PortraitError::TooLarge)
        ));
    }

    #[test]
    fn store_round_trips_and_misses() {
        let root = tempfile::tempdir().expect("temp dir");
        let store = PortraitStore::new(root.path().to_path_buf());
        assert_eq!(
            store.read_cached(ImageKind::Character, 90000001, PORTRAIT_SIZE),
            None
        );
        let bytes = generated_png(8, 8);
        store
            .write_cached(ImageKind::Character, 90000001, PORTRAIT_SIZE, &bytes)
            .expect("cache write");
        assert!(root.path().join("portraits/90000001_256.jpg").is_file());
        assert_eq!(
            store
                .read_cached(ImageKind::Character, 90000001, PORTRAIT_SIZE)
                .expect("cached bytes"),
            bytes
        );
        store.remove_cached(ImageKind::Character, 90000001, PORTRAIT_SIZE);
        assert_eq!(
            store.read_cached(ImageKind::Character, 90000001, PORTRAIT_SIZE),
            None
        );
    }

    #[test]
    fn semaphore_starts_with_the_bounded_permits() {
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::new(root.path().to_path_buf());
        assert_eq!(
            service.semaphore.available_permits(),
            MAX_CONCURRENT_FETCHES
        );
    }

    #[tokio::test]
    async fn fetch_decodes_from_the_image_service_shape() {
        let body = generated_png(8, 8);
        let (base, captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        let image = service
            .image(ImageKind::Character, 90000001, PORTRAIT_SIZE)
            .await
            .expect("fetch decodes");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
        let request = captured.await.expect("request captured");
        assert!(
            request.contains("GET /characters/90000001/portrait?size=256"),
            "unexpected request: {request}"
        );
    }

    #[tokio::test]
    async fn fetch_decodes_a_corporation_logo_from_the_image_service_shape() {
        let body = generated_png(8, 8);
        let (base, captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        let image = service
            .image(ImageKind::Corporation, 1000166, LOGO_SIZE)
            .await
            .expect("logo fetch decodes");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
        let request = captured.await.expect("request captured");
        assert!(
            request.contains("GET /corporations/1000166/logo?size=64"),
            "unexpected request: {request}"
        );
    }

    #[tokio::test]
    async fn fetch_decodes_an_alliance_logo_from_the_image_service_shape() {
        let body = generated_png(8, 8);
        let (base, captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        let image = service
            .image(ImageKind::Alliance, 99003581, LOGO_SIZE)
            .await
            .expect("logo fetch decodes");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
        let request = captured.await.expect("request captured");
        assert!(
            request.contains("GET /alliances/99003581/logo?size=64"),
            "unexpected request: {request}"
        );
    }

    #[tokio::test]
    async fn fetch_decodes_a_faction_logo_from_the_image_service_shape() {
        // Factions use the corporations endpoint in the image
        // server (design section 2): the request line proves the
        // test seam routes Faction to the corporations path.
        let body = generated_png(8, 8);
        let (base, captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        let image = service
            .image(ImageKind::Faction, 500001, LOGO_SIZE)
            .await
            .expect("faction logo fetch decodes");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
        let request = captured.await.expect("request captured");
        assert!(
            request.contains("/corporations/500001/logo?size=64"),
            "unexpected request: {request}"
        );
    }

    #[tokio::test]
    async fn fetch_maps_404_to_a_status_error() {
        let (base, _captured) = mock_bytes_server(404, b"missing".to_vec()).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        assert!(matches!(
            service
                .image(ImageKind::Corporation, 1000166, LOGO_SIZE)
                .await,
            Err(PortraitError::Status(404))
        ));
        // The live service does not 404 unknown ids: it returns a
        // shared 200 fallback image (logos design section 5). This
        // test only documents the status mapping against the mock.
    }

    #[tokio::test]
    async fn fetch_aborts_an_oversized_body() {
        let body = vec![7u8; MAX_IMAGE_BYTES + 1];
        let (base, _captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        assert!(matches!(
            service
                .image(ImageKind::Alliance, 99003581, LOGO_SIZE)
                .await,
            Err(PortraitError::TooLarge)
        ));
    }

    #[tokio::test]
    async fn cache_hit_makes_no_network_call() {
        let body = generated_png(8, 8);
        let (base, _captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let first = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        first
            .image(ImageKind::Character, 90000001, PORTRAIT_SIZE)
            .await
            .expect("first fetch fills cache");
        // Port 9 is unroutable: any network attempt here would fail,
        // so a successful portrait proves the cache served it.
        let second = PortraitService::with_client(
            PortraitClient::with_base_url("http://127.0.0.1:9".to_string()),
            root.path().to_path_buf(),
        );
        let image = second
            .image(ImageKind::Character, 90000001, PORTRAIT_SIZE)
            .await
            .expect("cache serves without network");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
    }

    #[tokio::test]
    async fn cache_is_isolated_by_kind() {
        let body = generated_png(8, 8);
        let (base, _captured) = mock_bytes_server(200, body).await;
        let root = tempfile::tempdir().expect("temp dir");
        let first = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        first
            .image(ImageKind::Corporation, 1000166, LOGO_SIZE)
            .await
            .expect("corporation fetch fills cache");
        // The same numeric id in another kind must not be served by
        // the corporation bytes: against an unroutable base the
        // alliance request fails, while a second corporation
        // request succeeds from cache with no network.
        let second = PortraitService::with_client(
            PortraitClient::with_base_url("http://127.0.0.1:9".to_string()),
            root.path().to_path_buf(),
        );
        assert!(
            second
                .image(ImageKind::Alliance, 1000166, LOGO_SIZE)
                .await
                .is_err(),
            "corporation bytes must not serve the alliance slot"
        );
        let image = second
            .image(ImageKind::Corporation, 1000166, LOGO_SIZE)
            .await
            .expect("corporation cache serves without network");
        assert_eq!(image.width(), 8);
        assert_eq!(image.height(), 8);
    }

    #[tokio::test]
    async fn faction_cache_is_isolated_from_corporation_cache() {
        // Bytes written under one kind are not read back under
        // another: the faction and corporation files are distinct
        // even for the same number (design section 9).
        let root = tempfile::tempdir().expect("temp dir");
        let store = PortraitStore::new(root.path().to_path_buf());
        let body = generated_png(8, 8);
        store
            .write_cached(ImageKind::Corporation, 500001, LOGO_SIZE, &body)
            .expect("corporation write");
        assert!(store
            .read_cached(ImageKind::Faction, 500001, LOGO_SIZE)
            .is_none());
        assert_eq!(
            store
                .read_cached(ImageKind::Corporation, 500001, LOGO_SIZE)
                .expect("corporation bytes readable"),
            body
        );
    }

    #[test]
    fn decode_preserves_png_alpha() {
        let bytes = generated_rgba_png(&[[255, 0, 0, 0], [0, 255, 0, 128], [0, 0, 255, 255]]);
        let decoded = decode_portrait(&bytes).expect("rgba png decodes");
        let rgba = decoded.to_rgba8();
        let pixels: Vec<[u8; 4]> = rgba.pixels().map(|p| p.0).collect();
        assert_eq!(
            pixels,
            vec![[255, 0, 0, 0], [0, 255, 0, 128], [0, 0, 255, 255]]
        );
    }

    #[tokio::test]
    async fn poisoned_cache_entry_is_refetched() {
        let root = tempfile::tempdir().expect("temp dir");
        let store = PortraitStore::new(root.path().to_path_buf());
        store
            .write_cached(ImageKind::Corporation, 1000166, LOGO_SIZE, b"not an image")
            .expect("poisoned write");
        let body = generated_png(8, 8);
        let (base, _captured) = mock_bytes_server(200, body).await;
        let service = PortraitService::with_client(
            PortraitClient::with_base_url(base),
            root.path().to_path_buf(),
        );
        let image = service
            .image(ImageKind::Corporation, 1000166, LOGO_SIZE)
            .await
            .expect("poisoned entry refetches");
        assert_eq!(image.width(), 8);
    }
}
