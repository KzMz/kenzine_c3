module kenzine::log;

import kenzine::core;
import kenzine::faults;
import std::io;
import std::core;

enum LogLevel : int(String prefix)
{
    FATAL = "[FATAL]:\t",
    ERROR = "[ERROR]:\t",
    WARNING = "[WARNING]:\t",
    INFO = "[INFO]:\t",
    DEBUG = "[DEBUG]:\t",
    TRACE = "[TRACE]:\t",
}

struct LogState
{
    File file;
    Path path;
}

struct LogParams
{
    String log_folder;
    String log_file;
}

def CoreSystem = kenzine::core::System(<LogState, LogParams>);
struct LogSystem(CoreSystem)
{
    LogState* state;
}

LogState* log_state = null;

fn void! LogSystem.initialize(LogSystem* self, LogState* state, LogParams* params) @dynamic
{
    self.state = state;
    log_state = self.state;

    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

$if($feature(PLATFORM_WEB)):

$else
    Path log_path = io::path::new(params.log_folder)!;
    defer log_path.free();

    if (!io::path::exists(log_path))
    {
        io::path::mkdir(log_path)!;
    }

    log_path = log_path.new_append(params.log_file)!;
    self.state.file = io::file::open(log_path.path_string, "a")!;
$endif
}

fn void! LogSystem.shutdown(LogSystem* self) @dynamic
{
$if($feature(PLATFORM_WEB)):

$else
    self.state.file.flush()!;
    self.state.file.close()!;
$endif
}

fn usz LogSystem.get_state_size(LogSystem* self) @dynamic
{
    return LogState.sizeof;
}

fn void! LogSystem.log(LogSystem* self, LogLevel level, String format, args...) @dynamic
{
    log(level, format, args)!;
}

fn void! log(LogLevel level, String format, args...)
{
    // TODO: add colors

    Allocator allocator = allocator::temp();
    @pool(allocator)
    {
        DString str = dstring::temp_with_capacity(format.len + args.len * 8);
        str.append(level.prefix);
        str.appendf(format, ...args);

        String message = str.copy_str(allocator);
        io::printn(message);

$if(!$feature(PLATFORM_WEB)):
        if (log_state != null && log_state.file.file != null)
        {
            log_state.file.write(message)!;
            log_state.file.write("\n")!;
            log_state.file.flush()!;
        }
$endif
    };
}