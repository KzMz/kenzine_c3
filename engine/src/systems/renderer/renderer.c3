module kenzine::renderer;

import kenzine::core;
import kenzine::faults;
import kenzine::common;

enum SupportedBackend
{
    WEBGPU,
    JS,
}

enum SupportedShaderFormat : int(String extension)
{
    WGSL = ".wgsl",
    SPIRV = ".spv",
}

fn SupportedShaderFormat format_from_string(String format)
{
    switch (format)
    {
        case "wgsl":
            return SupportedShaderFormat.WGSL;
        case "spirv":
            return SupportedShaderFormat.SPIRV;
    }

    return SupportedShaderFormat.WGSL;
}

enum SupportedShaderStage
{
    VERTEX,
    FRAGMENT,
}

fn SupportedShaderStage stage_from_string(String stage)
{
    switch (stage)
    {
        case "vertex":
            return SupportedShaderStage.VERTEX;
        case "fragment":
            return SupportedShaderStage.FRAGMENT;
    }

    return SupportedShaderStage.VERTEX;
}

struct RendererState
{
    SupportedBackend backend_type;
    RendererBackend backend;
}

struct VertexShaderParams
{
    ZString entry_point;
}

struct FragmentShaderParams
{
    ZString entry_point;
}

struct RendererRequirements
{
    uint max_vertex_attributes;
    uint max_vertex_buffers;
    uint max_buffer_size;
    uint max_vertex_buffer_stride;
    uint max_interstage_shader_components;
}

struct RendererParams
{
    SupportedBackend backend_type;

    Color4f clear_color;
    ZString device_label;
    usz swapchain_width;
    usz swapchain_height;

    RendererRequirements requirements;
}

struct RenderPacket
{
    double delta_time;
}

struct RendererSystem(kenzine::core::System(<RendererParams>))
{
    bool dummy;
}

RendererState renderer_state;

// TODO: see if there is a better way to do this
WebGPUBackend webGPU_backend;
JSBackend js_backend;

fn void! RendererSystem.initialize(RendererSystem* self, RendererParams* params) @dynamic
{
    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }
    
    renderer_state.backend_type = params.backend_type;

    switch (params.backend_type)
    {
        case SupportedBackend.WEBGPU:
            renderer_state.backend = &webGPU_backend;
            break;
        case SupportedBackend.JS:
            renderer_state.backend = &js_backend;
            break;
    }

    renderer_state.backend.initialize(params)!;
}

fn void! RendererSystem.draw(RendererSystem* self, RenderPacket* packet) @dynamic
{
    renderer_state.backend.begin_frame(packet.delta_time)!;

    renderer_state.backend.begin_renderpass(RenderPassType.WORLD)!;

    renderer_state.backend.draw_frame(packet.delta_time)!;

    renderer_state.backend.end_renderpass(RenderPassType.WORLD)!;

    renderer_state.backend.end_frame(packet.delta_time)!;
}

fn void! RendererSystem.shutdown(RendererSystem* self) @dynamic
{
    renderer_state.backend.shutdown()!;
}

fn void! RendererSystem.check_requirements(RendererSystem* self, RendererRequirements* requirements) @dynamic
{
    renderer_state.backend.check_requirements(requirements)!;
}