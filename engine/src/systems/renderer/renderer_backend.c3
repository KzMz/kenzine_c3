module kenzine::renderer;

import kenzine::common;

enum RenderPassType
{
    WORLD,
    UI,
}

interface RendererBackend
{
    fn void! initialize(RendererParams* params);
    fn void! shutdown();

    fn void! begin_frame(double delta_time);
    fn void! draw_frame(double delta_time);
    fn void! end_frame(double delta_time);

    fn void! begin_renderpass(RenderPassType type);
    fn void! end_renderpass(RenderPassType type);

    fn void! check_requirements(RendererRequirements* requirements);
}