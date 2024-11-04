import kenzine::app;
import kenzine::core::game;
import std::io;

import test_game;

fn void main()
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

    Game game;
    game.state_size = GameState.sizeof;
    game.config = config;
    game.init = &test_game::init;
    game.update = &test_game::update;
    game.render = &test_game::render;
    game.resize = &test_game::resize;
    game.shutdown = &test_game::shutdown;

    app::initialize(&game)!!;
    app::run()!!;
}