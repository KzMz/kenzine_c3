module kenzine::core;

fault SystemError
{
    STATE_IS_NULL,
    PARAMS_IS_NULL,
}

interface System
{
    fn void! initialize(void* state, void* params);
    fn void! shutdown();
    fn int get_state_size();
}