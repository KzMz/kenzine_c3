module kenzine::app;

import kenzine::core;
import kenzine::platform;
import kenzine::memory;
import kenzine::log;
import kenzine::event;

struct ApplicationConfig
{
    PlatformParams platform_params;
    LogParams log_params;

    float target_fps;
}

struct Application
{
    Game* game;
    Clock clock;
    bool running;
    bool suspended;
    int current_width;
    int current_height;
    double last_time;
    usz temp_mark;

    FrameState frame_state;
    double target_frame_time;

    MemorySystem memory_system;
    PlatformSystem platform_system;
    LogSystem log_system;
    EventSystem event_system;
}

struct FrameState
{
    double running_time;
    int frame_number;
}

fault ApplicationError
{
    APP_ALREADY_INITIALIZED,
}

Application* app;

fn void! Application.initialize(Application* self, Game* game)
{
    app = self;

    app.temp_mark = allocator::temp().used;

$if($feature(PLATFORM_WEB)):
    platform::wasm::initialize_wasm(game);
$endif

    if (game.app != null)
    {
        return ApplicationError.APP_ALREADY_INITIALIZED?;
    }

    MemoryParams memory_params;
    memory_params.default_allocator = allocator::heap();

    MemoryState memory_state;
    app.memory_system.initialize(&memory_state, &memory_params)!;

    game.state = memory::allocate(game.state_size, MemoryTag.GAME)!;

    game.app = app;
    app.game = game;
    app.running = true;
    app.suspended = false;

    LogState* log_state = memory::kallocate(LogState, MemoryTag.APP)!;
    app.log_system.initialize(log_state, &game.config.log_params)!;

    EventParams params;
    EventState* event_state = memory::kallocate(EventState, MemoryTag.APP)!;
    app.event_system.initialize(event_state, &params)!;

    subscribe_default_events()!;

    PlatformState* platform_state = memory::kallocate(PlatformState, MemoryTag.APP)!;
    app.platform_system.initialize(platform_state, &game.config.platform_params)!;

    app.log_system.log(LogLevel.INFO, "Systems initialized")!;

    game.initialize()!;
    game.resize(game.config.platform_params.width, game.config.platform_params.height)!;

    app.log_system.log(LogLevel.INFO, "Application initialized")!;

    memory::log_memory_report()!;
}

fn void! Application.run(Application* self)
{
    app.clock.start();
    app.clock.update();
    app.last_time = app.clock.elapsed_time;

    app.frame_state.running_time = 0;
    app.frame_state.frame_number = 0;
    app.target_frame_time = 1.0 / app.game.config.target_fps;

$if($feature(PLATFORM_WEB)):

$else
    defer app.shutdown()!!;

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

        app.game.update(delta_time)!;
        app.game.render(delta_time)!;

        // TODO: render packet

        double frame_end_time = platform::get_absolute_time();
        double frame_time = frame_end_time - frame_start_time;
        app.frame_state.running_time += frame_time;

        double sleep_time = app.target_frame_time - frame_time;
        bool limit_fps = false;
        if (sleep_time > 0 && limit_fps)
        {
            uint sleep_ms = (uint) (sleep_time * 1000);
            platform::sleep(sleep_ms);
        }

        app.frame_state.frame_number++;

        // TODO: input update
        app.last_time = current_time;
        allocator::temp().reset(app.temp_mark);
    }
$endif
}

fn void! Application.shutdown(Application* self)
{
    app.game.shutdown()!;
    memory::free(app.game.state, app.game.state_size, MemoryTag.GAME)!;

    app.running = false;
    app.suspended = false;

    app.platform_system.shutdown()!;
    memory::kfree(app.platform_system.state, PlatformState, MemoryTag.APP)!;

    app.event_system.shutdown()!;
    memory::kfree(app.event_system.state, EventState, MemoryTag.APP)!;

    app.log_system.log(LogLevel.INFO, "Application shutting down")!;
    app.log_system.shutdown()!;
    memory::kfree(app.log_system.state, LogState, MemoryTag.APP)!;

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