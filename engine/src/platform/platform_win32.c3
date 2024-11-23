module kenzine::platform::win32;

import std::io;
import kenzine::core;
import kenzine::faults;
import kenzine::event;

double clock_frequency = 0.0;

fn void! open_window(String title, uint width, uint height, uint x, uint y) @if(env::WIN32)
{
    if (platform::platform.hwnd_class_name == null)
    {
        platform::platform.hwnd_class_name = String.to_new_utf16("KenzineWindowClass").ptr!!;
    }

    platform::platform.h_instance = win32::get_module_handle(null);
    
    WndClass wndClass = 
    {
        .cbSize = WndClass.sizeof,
        .style = win32::CS_DBLCLKS,
        .lpfnWndProc = &window_proc,
        .hInstance = platform::platform.h_instance,
        .hIcon = win32::load_icon(platform::platform.h_instance, win32::IDI_APP),
        .hCursor = win32::load_cursor(null, win32::IDC_ARROW),
        .cbClsExtra = 0,
        .cbWndExtra = 0,
        .hbrBackground = null,
        .lpszClassName = platform::platform.hwnd_class_name,
        .lpszMenuName = (LPCWStr) 0,
    };

    if (win32::register_class(&wndClass) == 0)
    {
        Char16* t = String.to_new_utf16("Failed to register window class").ptr!!;
        defer free(t);

        Char16* msg = String.to_new_utf16("Error").ptr!!;
        defer free(msg);

        win32::message_box(null, t, msg, win32::MB_OK | win32::MB_ICONHAND);
        return PlatformError.COULD_NOT_REGISTER_CLASS?;
    }

    int window_x = x;
    int window_y = y;
    int window_width = width;
    int window_height = height;
    DWord window_style = win32::WS_OVERLAPPED | win32::WS_CAPTION | win32::WS_SYSMENU | win32::WS_THICKFRAME | win32::WS_MINIMIZEBOX | win32::WS_MAXIMIZEBOX;
    DWord window_ex_style = win32::WS_EX_APPWINDOW;

    win32::Rect window_rect;
    win32::adjust_window_rect(&window_rect, window_style, (win32::Bool) false, window_ex_style);

    window_x += window_rect.left;
    window_y += window_rect.top;
    window_width += window_rect.right - window_rect.left;
    window_height += window_rect.bottom - window_rect.top;

    platform::platform.title = String.to_new_utf16(title).ptr!!;

    platform::platform.h_window = win32::create_window(
        window_ex_style,
        wndClass.lpszClassName,
        platform::platform.title,
        window_style,
        window_x, window_y,
        window_width, window_height,
        (Hwnd) 0,
        (HMenu) 0,
        platform::platform.h_instance,
        null
    );

    if (platform::platform.h_window == null)
    {
        io::printfn("Failed to open window %d\n", win32::get_last_error());

        Char16* t = String.to_new_utf16("Failed to open window").ptr!!;
        defer free(t);
        
        Char16* msg = String.to_new_utf16("Error").ptr!!;
        defer free(msg);

        win32::message_box(null, t, msg, win32::MB_OK | win32::MB_ICONHAND);
        return PlatformError.COULD_NOT_OPEN_WINDOW?;
    }

    win32::show_window(platform::platform.h_window, win32::SW_SHOW);
}

fn void! close_window() @if(env::WIN32)
{
    if (platform::platform.h_window == null) return;

    win32::destroy_window(platform::platform.h_window);
    platform::platform.h_window = null;

    if (platform::platform.hwnd_class_name != null)
    {
        free(platform::platform.hwnd_class_name);
    }

    if (platform::platform.title != null)
    {
        free(platform::platform.title);
    }
}

fn LResult window_proc(Hwnd hWnd, uint msg, WParam wp, LParam lp) @private @if(env::WIN32)
{
    switch (msg)
    {
        case win32::WM_DESTROY:
        {
            win32::post_quit_message(0);
            return 0;
        }
        case win32::WM_ERASEBKGND:
        {
            return 1;
        }
        case win32::WM_CLOSE:
        {
            EventData event;
            (void) event::trigger((int) SystemEventCode.APPLICATION_QUIT, null, event);
            return 1;
        }
    }

    return win32::def_window_proc(hWnd, msg, wp, lp);
}

fn void clock_setup() @if(env::WIN32)
{
    LongLong frequency;
    win32::query_performance_frequency(&frequency);
    clock_frequency = 1.0 / frequency;
}

fn double get_absolute_time() @if(env::WIN32)
{
    if (clock_frequency == 0.0)
    {
        clock_setup();
    }

    LongLong now;
    win32::query_performance_counter(&now);
    return now * clock_frequency;
}

fn void handle_messages() @if(env::WIN32)
{
    Msg msg;
    while (win32::peek_message(&msg, null, 0, 0, win32::PM_REMOVE))
    {
        if (msg.message == win32::WM_QUIT)
        {
            break;
        }

        win32::translate_message(&msg);
        win32::dispatch_message(&msg);
    }
}