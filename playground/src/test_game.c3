import kenzine::core::game;
import kenzine::log;
import std::io;

struct GameState
{
    double delta_time;
}

struct TestGameFunctions(GameFunctions)
{
    char dummy;
}

fn void! TestGameFunctions.initialize(TestGameFunctions* functions, Game* game) @dynamic
{

}

fn void! TestGameFunctions.update(TestGameFunctions* functions, Game* game, double delta_time) @dynamic
{
    //io::printn(string::format("TestGameFunctions.update: %f", delta_time, allocator: allocator::temp()));
    //log::log(LogLevel.INFO, "%f", delta_time)!;
}

fn void! TestGameFunctions.render(TestGameFunctions* functions, Game* game, double delta_time) @dynamic
{

}

fn void! TestGameFunctions.resize(TestGameFunctions* functions, Game* game, int width, int height) @dynamic
{

}

fn void! TestGameFunctions.shutdown(TestGameFunctions* functions, Game* game) @dynamic
{

}