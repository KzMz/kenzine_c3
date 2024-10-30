import kenzine::app;
import kenzine::core::game;
import std::io;

fn void main()
{
    Game game;

    app::initialize(&game)!!;
    app::run()!!;
}