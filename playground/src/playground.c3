import kenzine::app;
import kenzine::core::game;
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
    };

    game.state_size = GameState.sizeof;
    game.config = config;
    game.functions = (GameFunctions) &functions;

    app.initialize(&game)!!;
    app.run()!!;
}