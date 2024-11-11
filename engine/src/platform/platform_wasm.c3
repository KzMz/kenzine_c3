module kenzine::platform::wasm;

import kenzine::core::game;
import kenzine::app;
import std::io::os;
import kenzine::log;

// Thanks to rexim https://github.com/c3lang/c3c/pull/1440
extern fn void wasm_write(void* buffer, usz buffer_len) @if($feature(PLATFORM_WEB));

extern fn void app_set_title(char* title, usz len) @if($feature(PLATFORM_WEB)) @extern("wasm_app_set_title");
extern fn void canvas_resize(usz width, usz height) @if($feature(PLATFORM_WEB)) @extern("wasm_canvas_resize");
extern fn void canvas_move(usz x, usz y) @if($feature(PLATFORM_WEB)) @extern("wasm_canvas_move");
extern fn void app_setup_loop() @if($feature(PLATFORM_WEB)) @extern("wasm_app_setup_loop");
extern fn double get_absolute_time() @if($feature(PLATFORM_WEB)) @extern("wasm_get_absolute_time");

fn void initialize_wasm(Game* game) @if($feature(PLATFORM_WEB))
{
    // Thanks to rexim https://github.com/c3lang/c3c/pull/1440
    os::native_fwrite_fn = fn usz!(void* ptr, char[] buffer)
    {
        wasm::wasm_write(&buffer[0], buffer.len);
        return buffer.len;
    };

    app_setup_loop();
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

    // TODO: render packet

    double frame_end_time = platform::get_absolute_time();
    double frame_time = frame_end_time - frame_start_time;
    app::app.frame_state.running_time += frame_time;

    app::app.frame_state.frame_number++;

    // TODO: input update
    app::app.last_time = current_time;
    allocator::temp().reset(app::app.temp_mark);
}