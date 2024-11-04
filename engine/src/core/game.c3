module kenzine::core::game;

import kenzine::app;

def GameInit = fn void!(Game* game);
def GameUpdate = fn void!(Game* game, double delta_time);
def GameRender = fn void!(Game* game, double delta_time);
def GameResize = fn void!(Game* game, int width, int height);
def GameShutdown = fn void!(Game* game);

struct Game
{
    ApplicationConfig config;

    Application* app;

    GameInit init;
    GameUpdate update;
    GameRender render;
    GameResize resize;
    GameShutdown shutdown;

    void* state; // Every game will implement its state differently
    usz state_size;
}

macro game_valid(game)
{
    return game != null && game.init != null && game.update != null && game.render != null && game.resize != null && game.shutdown != null;
}