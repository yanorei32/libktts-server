use axum::Router;
use axum::extract::{Json, State};
use axum::http::{StatusCode, header};
use axum::response::IntoResponse;
use axum::routing::{get, post};
use tokio::net::TcpListener;
use tokio::sync::{mpsc, oneshot};

#[derive(Clone)]
struct AppState {
    maximum_length: usize,
    worker: mpsc::Sender<crate::model::RequestContext>,
}

async fn root_handler() -> impl IntoResponse {
    (
        [(header::CONTENT_TYPE, "text/html")],
        include_str!("../assets/index.html"),
    )
}

async fn tts_handler(
    State(state): State<AppState>,
    Json(req): Json<crate::model::ApiRequest>,
) -> impl IntoResponse {
    if state.maximum_length != 0 && state.maximum_length < req.text.chars().count() {
        return (
            StatusCode::BAD_REQUEST,
            [(header::CONTENT_TYPE, "audio/wav")],
            format!("Maximum length ({}) exceeded", state.maximum_length).into_bytes(),
        );
    }

    let (resp_tx, resp_rx) = oneshot::channel::<crate::model::ResponseContext>();

    state
        .worker
        .send(crate::model::RequestContext {
            text: req.text,
            response: resp_tx,
        })
        .await
        .unwrap();

    let resp = resp_rx.await.unwrap();

    (
        StatusCode::OK,
        [(header::CONTENT_TYPE, "audio/wav")],
        resp.bytes,
    )
}

pub async fn serve(
    listener: TcpListener,
    worker_socket: mpsc::Sender<crate::model::RequestContext>,
    maximum_length: usize,
) -> Result<(), std::io::Error> {
    let app = Router::new()
        .route("/", get(root_handler))
        .route("/api/tts", post(tts_handler))
        .with_state(AppState {
            worker: worker_socket,
            maximum_length,
        });

    axum::serve(listener, app).await
}
