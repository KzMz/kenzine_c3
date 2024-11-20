module kenzine::platform::wasm;

import kenzine::core::game;
import kenzine::app;
import kenzine::log;
import kenzine::renderer;
import std::io::os;

// Thanks to rexim https://github.com/c3lang/c3c/pull/1440
extern fn void wasm_write(void* buffer, usz buffer_len) @if($feature(PLATFORM_WEB));
extern fn void wasm_load_resource(char* path, usz len) @if($feature(PLATFORM_WEB)) @extern("wasm_load_resource");

extern fn void app_set_title(char* title, usz len) @if($feature(PLATFORM_WEB)) @extern("app_set_title");
extern fn void canvas_resize(usz width, usz height) @if($feature(PLATFORM_WEB)) @extern("canvas_resize");
extern fn void canvas_move(usz x, usz y) @if($feature(PLATFORM_WEB)) @extern("canvas_move");
extern fn double get_absolute_time() @if($feature(PLATFORM_WEB)) @extern("get_absolute_time");

extern fn void renderer_set_clear_color(float r, float g, float b, float a) @if($feature(PLATFORM_WEB)) @extern("renderer_set_clear_color");
extern fn void renderer_initialize() @extern("renderer_initialize") @if($feature(PLATFORM_WEB));
extern fn void renderer_shutdown() @extern("renderer_shutdown") @if($feature(PLATFORM_WEB));
extern fn void renderer_begin_frame(double delta_time) @extern("renderer_begin_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_draw_frame(double delta_time) @extern("renderer_draw_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_end_frame(double delta_time) @extern("renderer_end_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_begin_renderpass(int type) @extern("renderer_begin_renderpass") @if($feature(PLATFORM_WEB));
extern fn void renderer_end_renderpass(int type) @extern("renderer_end_renderpass") @if($feature(PLATFORM_WEB));


fn void initialize_wasm(Game* game) @if($feature(PLATFORM_WEB))
{
    // Thanks to rexim https://github.com/c3lang/c3c/pull/1440
    os::native_fwrite_fn = fn usz!(void* ptr, char[] buffer)
    {
        wasm::wasm_write(&buffer[0], buffer.len);
        return buffer.len;
    };
}

fn void! web_loop() @export("app_loop") @wasm @if($feature(PLATFORM_WEB))
{
    platform::handle_messages();

    if (app::app.suspended)
    {
        return;
    }

    app::app.clock.update();
    double current_time = app::app.clock.elapsed_time;
    double delta_time = current_time - app::app.last_time;
    double frame_start_time = platform::get_absolute_time();

    app::app.game.update(delta_time)!;
    app::app.game.render(delta_time)!;

    RenderPacket packet;
    packet.delta_time = delta_time;
    app::app.renderer_system.draw(&packet)!;

    double frame_end_time = platform::get_absolute_time();
    double frame_time = frame_end_time - frame_start_time;
    app::app.frame_state.running_time += frame_time;

    app::app.frame_state.frame_number++;

    // TODO: input update
    app::app.last_time = current_time;
    allocator::temp().reset(app::app.temp_mark);
}