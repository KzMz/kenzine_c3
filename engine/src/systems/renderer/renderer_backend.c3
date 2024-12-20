module kenzine::renderer;

import kenzine::common;
import kenzine::resources;

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
    fn void! end_frame(double delta_time);

    fn void! begin_renderpass(RenderPassType type);
    fn void! end_renderpass(RenderPassType type);

    fn GeometryRenderData! upload_geometry(GeometryData* geometry);
    fn void! draw_geometry(GeometryRenderData* geometry);

    fn void! apply_global_uniforms(double delta_time);

    fn void! check_requirements(RendererRequirements* requirements);

    fn void! resize(usz width, usz height);
}