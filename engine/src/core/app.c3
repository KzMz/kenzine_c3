module kenzine::app;

import kenzine::core;
import kenzine::platform;
import kenzine::memory;
import kenzine::log;
import kenzine::event;
import kenzine::renderer;
import kenzine::resource;
import kenzine::resources;
import std::io;
import std::time;

struct ApplicationConfig
{
    PlatformParams platform_params;
    LogParams log_params;
    ResourceParams resource_params;
    RendererParams renderer_params;

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
    usz temp_mark;

    FrameState frame_state;
    double target_frame_time;

    MemorySystem memory_system;
    PlatformSystem platform_system;
    LogSystem log_system;
    EventSystem event_system;
    ResourceSystem resource_system;
    RendererSystem renderer_system;
}

struct FrameState
{
    NanoDuration running_time;
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
    app.memory_system.initialize(&memory_params)!;

    game.state = memory::allocate(game.state_size, MemoryTag.GAME)!;

    game.app = app;
    app.game = game;
    app.running = true;
    app.suspended = false;

    app.log_system.initialize(&game.config.log_params)!;

    EventParams params;
    app.event_system.initialize(&params)!;

    subscribe_default_events()!;

    app.platform_system.initialize(&game.config.platform_params)!;

    app.resource_system.initialize(&game.config.resource_params)!;

    if (game.config.renderer_params.swapchain_width == 0)
    {
        game.config.renderer_params.swapchain_width = game.config.platform_params.width;
    }
    if (game.config.renderer_params.swapchain_height == 0)
    {
        game.config.renderer_params.swapchain_height = game.config.platform_params.height;
    }

    app.renderer_system.initialize(&game.config.renderer_params)!;

    app.log_system.log(LogLevel.INFO, "Systems initialized")!;

    game.initialize()!;
    game.resize(game.config.platform_params.width, game.config.platform_params.height)!;

    app.log_system.log(LogLevel.INFO, "Application initialized")!;

$if(!$feature(PLATFORM_WEB)):
    memory::log_memory_report()!;
$endif
}

fn void! Application.run(Application* self)
{
    app.frame_state.running_time = 0;
    app.frame_state.frame_number = 0;
    app.target_frame_time = 1.0 / app.game.config.target_fps;

$if($feature(PLATFORM_WEB)):

$else
    app.clock = clock::now();
    defer app.shutdown()!!;

    while (app.running)
    {
        platform::handle_messages();

        if (app.suspended)
        {
            continue;
        }

        double delta_time = app.clock.mark().to_sec();
        Clock frame_clock = clock::now();

        app.game.update(delta_time)!;
        app.game.render(delta_time)!;

        RenderPacket packet;
        packet.init();
        packet.delta_time = delta_time;

        // TEMP
        Resource cube_geometry;
        resource::load(ResourceType.GEOMETRY, "plane2d", &cube_geometry)!;
        GeometryData* cube_geometry_data = resources::get_resource_data(&cube_geometry, GeometryData);
        packet.geometries.push(cube_geometry_data);
        // TEMP end

        app.renderer_system.draw(&packet)!;
        resource::unload(&cube_geometry)!;

        NanoDuration frame_time = frame_clock.mark();
        app.frame_state.running_time += frame_time;

        double sleep_time = app.target_frame_time - frame_time.to_sec();
        bool limit_fps = false;
        if (sleep_time > 0 && limit_fps)
        {
            uint sleep_ms = (uint) (sleep_time * 1000);
            platform::sleep(sleep_ms);
        }

        app.frame_state.frame_number++;

        // TODO: input update
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

    app.renderer_system.shutdown()!;

    app.resource_system.shutdown()!;
    app.platform_system.shutdown()!;

    app.event_system.shutdown()!;

    app.log_system.log(LogLevel.INFO, "Application shutting down")!;
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

    ushort key = event_data.data.ushorts[0];
    app.log_system.log(LogLevel.INFO, "Key event received: %d", key)!;

    return true;
}

fn bool! on_resize(uint event_code, void* sender, void* listener, EventData event_data)
{
    if (event_code != (uint) SystemEventCode.WINDOW_RESIZED)
    {
        return false;
    }

    int width = event_data.data.ints[0];
    int height = event_data.data.ints[1];

    if (width == app.current_width && height == app.current_height)
    {
        return false;
    }

    app.current_width = width;
    app.current_height = height;

    if (width == 0 || height == 0)
    {
        log::log(LogLevel.INFO, "Window minimized")!;
        app.suspended = true;
        return true;
    }
    else 
    {
        if (app.suspended)
        {
            log::log(LogLevel.INFO, "Window restored")!;
            app.suspended = false;
        }
        
        app.game.resize(width, height)!;
        app.renderer_system.resize(width, height)!;
    }

    log::log(LogLevel.INFO, "Window resized to: %d x %d", app.current_width, app.current_height)!;
    return true;
}