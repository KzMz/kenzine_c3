module kenzine::core::clock;

import kenzine::platform;

struct Clock
{
    double start_time;
    double elapsed_time;
}

fn void Clock.start(Clock* self) @dynamic
{
    self.start_time = platform::get_absolute_time();
    self.elapsed_time = 0.0;
}

fn void Clock.update(Clock* self) @dynamic
{
    if (self.start_time == 0.0)
    {
        return;
    }

    double current_time = platform::get_absolute_time();
    self.elapsed_time = current_time - self.start_time;
}

fn void Clock.stop(Clock* self) @dynamic
{
    self.start_time = 0.0;
    self.elapsed_time = 0.0;
}