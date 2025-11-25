use tokio::sync::oneshot;
use serde::Deserialize;

#[derive(Debug)]
pub struct RequestContext {
    pub text: String,
    pub response: oneshot::Sender<ResponseContext>,
}

#[derive(Debug)]
pub struct ResponseContext {
    pub bytes: Vec<u8>,
}

#[derive(Deserialize)]
pub struct ApiRequest {
    pub text: String,
}
