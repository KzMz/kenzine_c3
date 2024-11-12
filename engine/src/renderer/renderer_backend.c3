module kenzine::renderer;

interface RendererBackend
{
    fn void! initialize();
    fn void! shutdown();
}