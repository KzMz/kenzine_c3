module kenzine::renderer;

import kenzine::core;
import kenzine::faults;
import kenzine::common;

struct RendererState
{
    SupportedBackend backend_type;
    RendererBackend backend;
}

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

struct VertexShaderParams
{
    ZString entry_point;
}

struct FragmentShaderParams
{
    ZString entry_point;
}

struct RendererParams
{
    SupportedBackend backend_type;
    RendererBackend backend;

    Color clear_color;
    ZString device_label;
    usz swapchain_width;
    usz swapchain_height;
}

struct RenderPacket
{
    double delta_time;
}

def CoreSystem = kenzine::core::System(<RendererState, RendererParams>);
struct RendererSystem(CoreSystem)
{
    RendererState* state;
}

RendererState* renderer_state = null;

fn void! RendererSystem.initialize(RendererSystem* self, RendererState* state, RendererParams* params) @dynamic
{
    self.state = state;
    self.state.backend_type = params.backend_type;
    renderer_state = self.state;

    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    self.state.backend = params.backend;
    self.state.backend.initialize(params)!;
}

fn void! RendererSystem.draw(RendererSystem* self, RenderPacket* packet) @dynamic
{
    self.state.backend.begin_frame(packet.delta_time)!;

    self.state.backend.begin_renderpass(RenderPassType.WORLD)!;

    self.state.backend.draw_frame(packet.delta_time)!;

    self.state.backend.end_renderpass(RenderPassType.WORLD)!;

    self.state.backend.end_frame(packet.delta_time)!;
}

fn void! RendererSystem.shutdown(RendererSystem* self) @dynamic
{
    self.state.backend.shutdown()!;
}

fn usz RendererSystem.get_state_size(RendererSystem* self) @dynamic
{
    return RendererState.sizeof;
}