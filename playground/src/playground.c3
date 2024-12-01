import kenzine::app;
import kenzine::core::game;
import kenzine::renderer;
import kenzine::common;
import std::io;

import test_game;

TestGameFunctions functions;
Game game;
Application app;

fn void main() @export("main") @wasm
{
    ApplicationConfig config =
    {
        .platform_params = {
            .title = "Kenzine Playground",
            .width = 1280,
            .height = 720,
            .x = 100,
            .y = 100,
        },
        .log_params = {
            .log_folder = "logs",
            .log_file = "playground.log",
        },
        .target_fps = 60,
        .resource_params = {
            .max_loaders = 10,
            .base_asset_path = "assets",
        },
        .renderer_params = {
            .backend_type = SupportedBackend.WEBGPU,
            .device_label = "WebGPU Device",
            .clear_color = common::Color { 0.9, 0.1, 0.2, 1.0 },
            .requirements = {
                .max_vertex_attributes = 1,
                .max_vertex_buffers = 1,
                .max_buffer_size = 6 * 2 * float.sizeof,
                .max_vertex_buffer_stride = 2 * float.sizeof,
            },
        },
    };

$if($feature(PLATFORM_WEB)):
    config.renderer_params.backend_type = SupportedBackend.JS;
$endif

    game.state_size = GameState.sizeof;
    game.config = config;
    game.functions = (GameFunctions) &functions;

    app.initialize(&game)!!;
    app.run()!!;
}