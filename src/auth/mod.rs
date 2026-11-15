//! EVE SSO authentication: PKCE OAuth, localhost callback, token storage.
//! Token values are never logged (`[AUTH]` tag).

pub mod callback_server;
pub mod oauth;
pub mod token_store;

pub use callback_server::{CallbackParams, CallbackServer};
pub use oauth::{
    build_authorize_url, create_authorization_request, exchange_code, generate_pkce,
    generate_state, parse_jwt_claims, refresh_access_token, revoke_token, AuthorizationRequest,
    JwtClaims, PkcePair, TokenResponse,
};
pub use token_store::{AccessToken, RefreshToken, StoredTokens, TokenStore};
