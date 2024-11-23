module kenzine::core(<Params>);

interface System
{
    fn void! initialize(Params* params);
    fn void! shutdown();
}