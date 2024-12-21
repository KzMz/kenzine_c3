module kenzine::renderer::js;

import kenzine::common;
import kenzine::platform::wasm;

import kenzine::resource;
import kenzine::resources;
import kenzine::log;

struct JSBackend(RendererBackend)
{
    bool dummy;
}

fn void! JSBackend.initialize(JSBackend* self, RendererParams* params) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_set_clear_color(&params.clear_color);
    wasm::renderer_initialize();
$endif
}

fn void! JSBackend.shutdown(JSBackend* self) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_shutdown();
$endif
}

fn void! JSBackend.begin_frame(JSBackend* self, double delta_time) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_begin_frame(delta_time);
$endif
}

fn void! JSBackend.draw_geometry(JSBackend* self, GeometryRenderData* geometry, usz instance_id) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_draw_frame();
$endif
}

fn GeometryRenderData! JSBackend.upload_geometry(JSBackend* self, GeometryData* geometry) @dynamic
{
    return
    {
       .geometry = geometry,
       .index_offset = 0,
       .vertex_offset = 0,
    };
}

fn void! JSBackend.end_frame(JSBackend* self, double delta_time) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_end_frame(delta_time);
$endif
}

fn void! JSBackend.begin_renderpass(JSBackend* self, RenderPassType type) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_begin_renderpass((int) type);
$endif
}

fn void! JSBackend.end_renderpass(JSBackend* self, RenderPassType type) @dynamic
{
$if($feature(PLATFORM_WEB)):
    wasm::renderer_end_renderpass((int) type);
$endif
}

fn void! JSBackend.check_requirements(JSBackend* self, RendererRequirements* requirements) @dynamic
{
    
}

fn void! JSBackend.resize(JSBackend* self, usz width, usz height) @dynamic
{

}

fn void! JSBackend.apply_global_uniforms(JSBackend* self, double delta_time) @dynamic
{

}

fn void! JSBackend.apply_instance_uniforms(JSBackend* self, int instance_id, double delta_time) @dynamic
{

}