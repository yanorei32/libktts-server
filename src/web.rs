use axum::Router;
use axum::extract::{Json, State};
use axum::http::header;
use axum::response::IntoResponse;
use axum::routing::{get, post};
use tokio::net::TcpListener;
use tokio::sync::{mpsc, oneshot};

#[derive(Clone)]
struct AppState {
    worker: mpsc::Sender<crate::model::RequestContext>,
}

async fn root_handler() -> impl IntoResponse {
    ([(header::CONTENT_TYPE, "text/html")], include_str!("../assets/index.html"))
}

async fn tts_handler(
    State(state): State<AppState>,
    Json(api_req): Json<crate::model::ApiRequest>,
) -> impl IntoResponse {
    let (resp_tx, resp_rx) = oneshot::channel::<crate::model::ResponseContext>();

    state
        .worker
        .send(crate::model::RequestContext {
            text: api_req.text,
            response: resp_tx,
        })
        .await
        .unwrap();

    let resp = resp_rx.await.unwrap();

    ([(header::CONTENT_TYPE, "audio/wav")], resp.bytes)
}

pub async fn serve(
    listener: TcpListener,
    worker_socket: mpsc::Sender<crate::model::RequestContext>,
) -> Result<(), std::io::Error> {
    let app = Router::new()
        .route("/", get(root_handler))
        .route("/api/tts", post(tts_handler))
        .with_state(AppState {
            worker: worker_socket,
        });

    axum::serve(listener, app).await
}
