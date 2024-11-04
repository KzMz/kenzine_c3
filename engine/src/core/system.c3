module kenzine::core(<State, Params>);

interface System
{
    fn void! initialize(State* state, Params* params);
    fn void! shutdown();
    fn usz get_state_size();
}