module kenzine::app;

import kenzine::core;
import kenzine::platform;
import kenzine::memory;
import kenzine::log;
import kenzine::event;

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
    LogSystem log_system;
    EventSystem event_system;
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

    LogParams log_params;
    log_params.log_folder = "logs";
    log_params.log_file = "engine.log";

    // TODO: alloc log state
    LogState log_state;

    app.log_system.initialize(&log_state, &log_params)!;

    EventParams params;

    // TODO: alloc event state
    EventState event_state;
    app.event_system.initialize(&event_state, &params)!;

    subscribe_default_events()!;

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
    app.event_system.shutdown()!;
    app.log_system.shutdown()!;
    app.memory_system.shutdown()!;
}

fn void! subscribe_default_events()
{
    app.event_system.subscribe((uint) SystemEventCode.APPLICATION_QUIT, &app, &on_app_quit)!;
    app.event_system.subscribe((uint) SystemEventCode.KEY_PRESSED, &app, &on_key_pressed_or_released)!;
    app.event_system.subscribe((uint) SystemEventCode.KEY_RELEASED, &app, &on_key_pressed_or_released)!;
    app.event_system.subscribe((uint) SystemEventCode.WINDOW_RESIZED, &app, &on_resize)!;
}

fn bool! on_app_quit(uint event_code, void* sender, void* listener, EventData event_data)
{
    if (event_code != (uint) SystemEventCode.APPLICATION_QUIT)
    {
        return false;
    }

    app.log_system.log(LogLevel.INFO, "Application quit event received")!;
    app.running = false;
    return true;
}

fn bool! on_key_pressed_or_released(uint event_code, void* sender, void* listener, EventData event_data)
{
    if (event_code != (uint) SystemEventCode.KEY_PRESSED && event_code != (uint) SystemEventCode.KEY_RELEASED)
    {
        return false;
    }

    ushort key = *(ushort*) &&event_data.data[0:2];
    app.log_system.log(LogLevel.INFO, "Key event received: %d", key)!;

    return true;
}

fn bool! on_resize(uint event_code, void* sender, void* listener, EventData event_data)
{
    if (event_code != (uint) SystemEventCode.WINDOW_RESIZED)
    {
        return false;
    }

    int width = *(int*) &&event_data.data[0:4];
    int height = *(int*) &&event_data.data[4:8];

    if (width == app.current_width && height == app.current_height)
    {
        return false;
    }

    app.current_width = width;
    app.current_height = height;

    if (width == 0 || height == 0)
    {
        app.log_system.log(LogLevel.INFO, "Window minimized")!;
        app.suspended = true;
        return true;
    }
    else 
    {
        if (app.suspended)
        {
            app.log_system.log(LogLevel.INFO, "Window restored")!;
            app.suspended = false;
        }
        
        // TODO: game resize
        // TODO: renderer resize
    }

    app.log_system.log(LogLevel.INFO, "Window resized to: %d x %d", width, height)!;
    return true;
}