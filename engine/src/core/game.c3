module kenzine::core::game;

import kenzine::app;

interface GameFunctions
{
    fn void! initialize(Game* game);
    fn void! update(Game* game, double delta_time);
    fn void! render(Game* game, double delta_time);
    fn void! resize(Game* game, int width, int height);
    fn void! shutdown(Game* game);
}

struct Game
{
    ApplicationConfig config;

    Application* app;
    GameFunctions functions;

    void* state; // Every game will implement its state differently
    usz state_size;
}

fn void! Game.initialize(Game* self)
{
    self.functions.initialize(self)!;
}

fn void! Game.update(Game* self, double delta_time)
{
    self.functions.update(self, delta_time)!;
}

fn void! Game.render(Game* self, double delta_time)
{
    self.functions.render(self, delta_time)!;
}

fn void! Game.resize(Game* self, int width, int height)
{
    self.functions.resize(self, width, height)!;
}

fn void! Game.shutdown(Game* self)
{
    self.functions.shutdown(self)!;
}