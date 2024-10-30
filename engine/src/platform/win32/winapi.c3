module kenzine::platform::win32;

distinct Handle = inline void*;

distinct HInstance = inline Handle;
distinct HIcon = inline Handle;
distinct Hwnd = inline Handle;
distinct HCursor = inline Handle;
distinct HBrush = inline Handle;
distinct HMenu = inline Handle;

def LPCWStr = Char16*;
def LPCStr = char*;

def Long = int;
def LongPtr = iptr;
def LResult = LongPtr;
def LParam = LongPtr;
def ULongPtr = uptr;
def UIntPtr = uptr;
def WParam = UIntPtr;
def Word = ushort;
def DWord = uint;
def Bool = int;
def LongLong = long;

def WndProc = fn LResult(Hwnd, uint, WParam, LParam);

struct WndClass
{
	CUInt cbSize;
	CUInt style;
	WndProc lpfnWndProc;
	CInt cbClsExtra;
	CInt cbWndExtra;
	HInstance hInstance;
	HIcon hIcon;
	HCursor hCursor;
	HBrush hbrBackground;
	LPCWStr lpszMenuName;
	LPCWStr lpszClassName;
	HIcon hIconSm;
}

struct Rect 
{
    Long left;
    Long top;
    Long right;
    Long bottom;
}

struct Point 
{
	Long x;
	Long y;
}

struct Msg
{
	Hwnd hwnd;
	CUInt message;
	WParam wParam;
	LParam lParam;
	DWord time;
	Point pt;
	DWord lPrivate;
}

macro make_int_resource($i) {
    return (LPCWStr)(ULongPtr)(Word)$i;
}

const DWord CS_OWNDC = 0x0020;
const DWord CS_DBLCLKS = 0x0008;
const LPCWStr IDI_APP = make_int_resource(32512);
const LPCWStr IDC_ARROW = make_int_resource(32512);

// MessageBox constants
const uint MB_OK = 0x00000000;
const uint MB_OKCANCEL = 0x00000001;
const uint MB_ABORTRETRYIGNORE = 0x00000002;
const uint MB_YESNOCANCEL = 0x00000003;
const uint MB_YESNO = 0x00000004;
const uint MB_RETRYCANCEL = 0x00000005;
const uint MB_CANCELTRYCONTINUE = 0x00000006;
const uint MB_ICONHAND = 0x00000010;
const uint MB_ICONQUESTION = 0x00000020;
const uint MB_ICONEXCLAMATION = 0x00000030;
const uint MB_ICONASTERISK = 0x00000040;

// Window constants
const DWord WS_OVERLAPPED = 0x00000000;
const DWord WS_CAPTION = 0x00C00000;
const DWord WS_SYSMENU = 0x00080000;
const DWord WS_THICKFRAME = 0x00040000;
const DWord WS_MINIMIZEBOX = 0x00020000;
const DWord WS_MAXIMIZEBOX = 0x00010000;

// Window ex constants
const DWord WS_EX_APPWINDOW = 0x00040000;

// Shown constants
const int SW_SHOW = 5;

// Peek message constants
const uint PM_NOREMOVE = 0x0000;
const uint PM_REMOVE = 0x0001;

// Message constants
const uint WM_DESTROY = 0x0002;
const uint WM_CLOSE = 0x0010;
const uint WM_ERASEBKGND = 0x0014;

extern fn HInstance get_module_handle(LPCWStr lpc) @extern("GetModuleHandleW");
extern fn HIcon load_icon(HInstance hInstance, LPCWStr lpIconName) @extern("LoadIconW");
extern fn HCursor load_cursor(HInstance hInstance, LPCWStr lpCursorName) @extern("LoadCursorW");

extern fn short register_class(WndClass* lpWndClass) @extern("RegisterClassExW");
extern fn Bool adjust_window_rect(Rect* lpRect, DWord dwStyle, Bool bMenu, DWord dwExStyle) @extern("AdjustWindowRectEx");
extern fn Hwnd create_window(DWord, LPCWStr, LPCWStr, DWord, int, int, int, int, Hwnd, HMenu, HInstance, void*) @extern("CreateWindowExW");
extern fn Bool show_window(Hwnd hWnd, int nCmdShow) @extern("ShowWindow");
extern fn LResult def_window_proc(Hwnd hWnd, uint msg, WParam wParam, LParam lParam) @extern("DefWindowProcW");
extern fn Bool destroy_window(Hwnd hWnd) @extern("DestroyWindow");

extern fn int message_box(Hwnd hWnd, LPCWStr lpText, LPCWStr lpCaption, uint uType) @extern("MessageBoxW");

extern fn DWord get_last_error() @extern("GetLastError");

extern fn Bool query_performance_frequency(LongLong* lpFrequency) @extern("QueryPerformanceFrequency");
extern fn Bool query_performance_counter(LongLong* lpPerformanceCount) @extern("QueryPerformanceCounter");

extern fn Bool peek_message(Msg*, Hwnd, uint, uint, uint) @extern("PeekMessageA");
extern fn Bool translate_message(Msg* lpMsg) @extern("TranslateMessage");
extern fn LResult dispatch_message(Msg* lpMsg) @extern("DispatchMessageA");
extern fn Bool post_quit_message(int nExitCode) @extern("PostQuitMessage");