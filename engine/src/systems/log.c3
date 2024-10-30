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

struct LogSystem(kenzine::core::System(<LogState, LogParams>))
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

    Path log_path = io::path::new(params.log_folder)!;
    if (!io::path::exists(log_path))
    {
        io::path::mkdir(log_path)!;
    }

    log_path = log_path.new_append(params.log_file)!;
    self.state.file = io::file::open(log_path.path_string, "a")!;
}

fn void! LogSystem.shutdown(LogSystem* self) @dynamic
{
    self.state.file.flush()!;
    self.state.file.close()!;
}

fn int LogSystem.get_state_size(LogSystem* self) @dynamic
{
    return LogState.sizeof;
}

fn void! LogSystem.log(LogSystem*self, LogLevel level, String format, args...) @dynamic
{
    log(level, format, args)!;
}

fn void! log(LogLevel level, String format, args...)
{
    // TODO: add colors

    DString log_message = dstring::new(level.prefix);
    defer log_message.free();

    log_message.append(format);

    io::printfn(log_message.str_view(), args)!;

    if (log_state != null)
    {
        log_state.file.write(log_message.str_view())!;
    }
}