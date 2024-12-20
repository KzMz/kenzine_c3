module kenzine::renderer;

import kenzine::core;
import kenzine::faults;
import kenzine::common;
import kenzine::resources;
import kenzine::log;

import std::collections::list;
import std::collections::map;

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

struct GeometryRenderData
{
    GeometryData* geometry;

    usz vertex_offset;
    usz index_offset;
}

struct RendererState
{
    SupportedBackend backend_type;
    RendererBackend backend;

    HashMap(<usz, GeometryRenderData>) geometry_render_data;
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
    uint max_bind_groups;
    uint max_uniform_buffers_per_shader_stage;
    uint max_uniform_buffer_binding_size;
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
    List(<GeometryData*>) geometries; // TEMP
}

fn void RenderPacket.init(RenderPacket* self)
{
    self.delta_time = 0.0;

    // Should we use kenzine_allocator here? Using tmp as it will be cleared every frame and maybe
    // we don't want to allocate memory for this every time
    self.geometries.temp_init();
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

    renderer_state.geometry_render_data.new_init(); // TODO: see if we need to use kenzine_allocator

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

    renderer_state.backend.apply_global_uniforms(packet.delta_time)!;

    // for each geometry in packet.geometry_resources
    //      get material when available
    //      apply material instance
    //      apply geometry model matrix
    //      draw geometry
    for (usz i = 0; i < packet.geometries.len(); i++)
    {
        GeometryData* geometry = packet.geometries[i];
        if (geometry == null) continue;

        if (!renderer_state.geometry_render_data.has_key(geometry.resource_id))
        {
            GeometryRenderData render_data;
            render_data = renderer_state.backend.upload_geometry(geometry)!;

            renderer_state.geometry_render_data.set(geometry.resource_id, render_data);
        }

        GeometryRenderData* geom_data = renderer_state.geometry_render_data.get_ref(geometry.resource_id)!;
        if (geom_data == null) continue;

        geom_data.geometry = geometry; // IMPORTANT to update the slice ptr
        renderer_state.backend.draw_geometry(geom_data)!;
    }

    renderer_state.backend.end_renderpass(RenderPassType.WORLD)!;

    renderer_state.backend.end_frame(packet.delta_time)!;
}

fn void! RendererSystem.resize(RendererSystem* self, int width, int height)
{
    renderer_state.backend.resize((usz) width, (usz) height)!;
}

fn void! RendererSystem.shutdown(RendererSystem* self) @dynamic
{
    renderer_state.backend.shutdown()!;
    renderer_state.geometry_render_data.clear();
}

fn void! RendererSystem.check_requirements(RendererSystem* self, RendererRequirements* requirements) @dynamic
{
    renderer_state.backend.check_requirements(requirements)!;
}