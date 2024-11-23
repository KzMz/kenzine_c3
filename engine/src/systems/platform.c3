module kenzine::platform;

import kenzine::core;
import kenzine::faults;

fault PlatformError
{
    COULD_NOT_REGISTER_CLASS,
    COULD_NOT_OPEN_WINDOW,
}

struct PlatformState
{
    HInstance h_instance @if(env::WIN32);
    Hwnd h_window @if(env::WIN32);
    Char16* hwnd_class_name @if(env::WIN32);
    Char16* title @if(env::WIN32);

    char dummy;
}

struct PlatformParams
{
    String title;
    uint width;
    uint height;
    uint x;
    uint y;
}

struct PlatformSystem(kenzine::core::System(<PlatformParams>))
{
    bool dummy;
}

PlatformState platform;

fn void! PlatformSystem.initialize(PlatformSystem* self, PlatformParams* params) @dynamic
{
    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    $if(env::WIN32):
        win32::open_window(params.title, params.width, params.height, params.x, params.y)!;
        win32::clock_setup();
    $endif

    $if($feature(PLATFORM_WEB)):
        wasm::app_set_title(&params.title[0], params.title.len);
        wasm::canvas_resize(params.width, params.height);
        wasm::canvas_move(params.x, params.y);
    $endif
}

fn void! PlatformSystem.shutdown(PlatformSystem* self) @dynamic
{
    $if(env::WIN32):
        win32::close_window()!;
    $endif
}

fn usz PlatformSystem.get_state_size(PlatformSystem* self) @dynamic
{
    return PlatformState.sizeof;
}

fn void sleep(uint milliseconds)
{
    $if(env::WIN32):
        win32::sleep(milliseconds);
    $endif
}

fn double get_absolute_time()
{
    $if(env::WIN32):
        return win32::get_absolute_time();
    $endif
    $if($feature(PLATFORM_WEB)):
        return wasm::get_absolute_time();
    $endif
}

fn void handle_messages()
{
    $if(env::WIN32):
        win32::handle_messages();
    $endif
}