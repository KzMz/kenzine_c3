module kenzine::app;

import kenzine::core;
import kenzine::platform;
import kenzine::memory;

struct Application
{
    Game* game;
    Clock clock;
    bool running;
    bool suspended;
    int current_width;
    int current_height;
    double last_time;

    MemorySystem memory_system;
    PlatformSystem platform_system;
}

fault ApplicationError
{
    GAME_IS_NULL,
    APP_ALREADY_INITIALIZED,
}

Application app;

fn void! initialize(Game* game)
{
    if (game == null)
    {
        return ApplicationError.GAME_IS_NULL?;
    }

    if (game.app != null)
    {
        return ApplicationError.APP_ALREADY_INITIALIZED?;
    }

    MemoryParams memory_params;
    memory_params.default_allocator = allocator::heap();

    MemoryState memory_state;
    app.memory_system.initialize(&memory_state, &memory_params)!;

    // TODO: alloc game state

    game.app = &app;
    app.game = game;
    app.running = true;
    app.suspended = false;

    // TODO: retrieve this from game
    PlatformParams platform_params;
    platform_params.title = "Kenzine";
    platform_params.width = 1280;
    platform_params.height = 720;
    platform_params.x = 100;
    platform_params.y = 100;

    // TODO: alloc platform state
    PlatformState platform_state;
    app.platform_system.initialize(&platform_state, &platform_params)!;
}

fn void! run()
{
    app.clock.start();
    app.clock.update();
    app.last_time = app.clock.elapsed_time;

    double running_time = 0;
    int frames = 0;
    float target_fps = 60.0;
    double target_frame_time = 1.0 / target_fps;

    while (app.running)
    {
        platform::handle_messages();

        if (app.suspended)
        {
            continue;
        }

        app.clock.update();
        double current_time = app.clock.elapsed_time;
        double delta_time = current_time - app.last_time;
        double frame_start_time = platform::get_absolute_time(); 

        // TODO: game update
        // TODO: game render

        // TODO: render packet

        double frame_end_time = platform::get_absolute_time();
        double frame_time = frame_end_time - frame_start_time;
        running_time += frame_time;

        double sleep_time = target_frame_time - frame_time;
        bool limit_fps = false;
        if (sleep_time > 0 && limit_fps)
        {
            uint sleep_ms = (uint) (sleep_time * 1000);

            // TODO: platform sleep
        }

        frames++;

        // TODO: input update
        app.last_time = current_time;
    }

    shutdown()!; 
}

fn void! shutdown()
{
    // TODO: game shutdown
    app.running = false;
    app.suspended = false;

    app.platform_system.shutdown()!;
    app.memory_system.shutdown()!;
}