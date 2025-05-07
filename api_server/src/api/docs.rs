
use axum::{
    http::{header, StatusCode},
    response::{Html, IntoResponse},
    routing::get,
    Router,
};

use tokio::fs;

use crate::api::AppState;

pub fn docs_routes() -> Router<AppState> {
    Router::<AppState>::new()
        .route("/api/docs", get(serve_swagger_ui))
        .route("/api/docs/swagger.yaml", get(serve_swagger_yaml))
}

async fn serve_swagger_ui() -> impl IntoResponse {
    let html = r##"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>LeakLens API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui.css">
    <style>
        html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
        *, *:before, *:after { box-sizing: inherit; }
        body { margin: 0; background: #fafafa; }
        .swagger-ui .topbar { background-color: #1b1b1b; }
        .swagger-ui .info .title { color: #333; font-size: 36px; }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.9.0/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            const ui = SwaggerUIBundle({
                url: "/api/docs/swagger.yaml",
                dom_id: "#swagger-ui",
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                layout: "StandaloneLayout"
            });
            window.ui = ui;
        };
    </script>
</body>
</html>
    "##;

    Html(html)
}

async fn serve_swagger_yaml() -> impl IntoResponse {
    match fs::read_to_string("swagger.yaml").await {
        Ok(content) => (
            StatusCode::OK,
            [(header::CONTENT_TYPE, "text/yaml")],
            content,
        )
            .into_response(),
        Err(_) => (
            StatusCode::NOT_FOUND,
            "OpenAPI specification file not found",
        )
            .into_response(),
    }
}