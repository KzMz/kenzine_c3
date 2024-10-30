module kenzine::platform;

import kenzine::core;

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
}

struct PlatformParams
{
    String title;
    uint width;
    uint height;
    uint x;
    uint y;
}

struct PlatformSystem(kenzine::core::System)
{
    PlatformState* state;
}

PlatformState* platform = null;

fn void! PlatformSystem.initialize(PlatformSystem* self, void* state, void* params) @dynamic
{
    self.state = (PlatformState*) state;
    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    platform = self.state;

    PlatformParams* p = (PlatformParams*) params;
    if (p == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    $if(env::WIN32):
        win32::open_window(p.title, p.width, p.height, p.x, p.y)!;
        win32::clock_setup();
    $endif
}

fn void! PlatformSystem.shutdown(PlatformSystem* self) @dynamic
{
    $if(env::WIN32):
        win32::close_window()!;
    $endif
}

fn int PlatformSystem.get_state_size(PlatformSystem* self) @dynamic
{
    return PlatformState.sizeof;
}

fn double get_absolute_time()
{
    $if(env::WIN32):
        return win32::get_absolute_time();
    $endif
}

fn void handle_messages()
{
    $if(env::WIN32):
        win32::handle_messages();
    $endif
}