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

struct LogSystem(kenzine::core::System(<LogParams>))
{
    bool dummy;
}

LogState log_state;

fn void! LogSystem.initialize(LogSystem* self, LogParams* params) @dynamic
{
    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

$if($feature(PLATFORM_WEB)):

$else
    Path log_path = io::path::temp_new(params.log_folder)!;

    if (!io::path::exists(log_path))
    {
        io::path::mkdir(log_path)!;
    }

    log_path = log_path.new_append(params.log_file)!;
    log_state.file = io::file::open(log_path.path_string, "a")!;
$endif
}

fn void! LogSystem.shutdown(LogSystem* self) @dynamic
{
$if($feature(PLATFORM_WEB)):

$else
    log_state.file.flush()!;
    log_state.file.close()!;
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
        if (log_state.file.file != null)
        {
            log_state.file.write(message)!;
            log_state.file.write("\n")!;
            log_state.file.flush()!;
        }
$endif
    };
}