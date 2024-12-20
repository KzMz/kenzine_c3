module kenzine::platform::wasm;

import kenzine::core::game;
import kenzine::memory;
import kenzine::app;
import kenzine::log;
import kenzine::renderer;
import kenzine::resources;
import kenzine::resource;
import kenzine::utils;
import kenzine::math;
import kenzine::common;

import std::io::os;
import std::time;

// Thanks to rexim https://github.com/c3lang/c3c/pull/1440
extern fn void wasm_write(void* buffer, usz buffer_len) @if($feature(PLATFORM_WEB));

extern fn void app_set_title(char* title, usz len) @if($feature(PLATFORM_WEB)) @extern("app_set_title");
extern fn void canvas_resize(usz width, usz height) @if($feature(PLATFORM_WEB)) @extern("canvas_resize");
extern fn void canvas_move(usz x, usz y) @if($feature(PLATFORM_WEB)) @extern("canvas_move");
extern fn double get_absolute_time() @if($feature(PLATFORM_WEB)) @extern("get_absolute_time");

extern fn void renderer_set_clear_color(Color4f* c) @if($feature(PLATFORM_WEB)) @extern("renderer_set_clear_color");
extern fn void renderer_initialize() @extern("renderer_initialize") @if($feature(PLATFORM_WEB));
extern fn void renderer_shutdown() @extern("renderer_shutdown") @if($feature(PLATFORM_WEB));
extern fn void renderer_begin_frame(double delta_time) @extern("renderer_begin_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_draw_frame() @extern("renderer_draw_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_end_frame(double delta_time) @extern("renderer_end_frame") @if($feature(PLATFORM_WEB));
extern fn void renderer_begin_renderpass(int type) @extern("renderer_begin_renderpass") @if($feature(PLATFORM_WEB));
extern fn void renderer_end_renderpass(int type) @extern("renderer_end_renderpass") @if($feature(PLATFORM_WEB));

fn void initialize_wasm(Game* game) @if($feature(PLATFORM_WEB))
{
    // Thanks to rexim https://github.com/c3lang/c3c/pull/1440
    os::native_fwrite_fn = fn usz!(void* ptr, char[] buffer)
    {
        wasm::wasm_write(&buffer[0], buffer.len);
        return buffer.len;
    };
}

fn void! web_loop(double delta_time) @export("app_loop") @wasm @if($feature(PLATFORM_WEB))
{
    platform::handle_messages();

    if (app::app.suspended)
    {
        return;
    }

    app::app.game.update(delta_time)!;
    app::app.game.render(delta_time)!;

    RenderPacket packet;
    packet.delta_time = delta_time;
    app::app.renderer_system.draw(&packet)!;

    app::app.frame_state.running_time += (NanoDuration) time::from_float(delta_time);

    app::app.frame_state.frame_number++;

    // TODO: input update
    allocator::temp().reset(app::app.temp_mark);
}

// Resources

fn Resource* load_resource(ResourceType type, void* name, usz name_len) @export("load_resource") @wasm @if($feature(PLATFORM_WEB))
{
    char[] resource_name = utils::ptr_to_slice_string(name, name_len);

    Resource* resource = resources::new((String) resource_name, type);

    resource::load(type, (String) resource_name, resource)!!;
    return resource;
}

fn void unload_resource(Resource* resource) @export("unload_resource") @wasm @if($feature(PLATFORM_WEB))
{
    if (resource == null) 
    {
        return;
    }

    memory::kfree(resource, Resource, resources::get_memory_tag(resource.type))!!;
}

// Shader Resources

fn char* shader_get_code(Resource* resource) @export("shader_get_code") @wasm @if($feature(PLATFORM_WEB))
{
    if (resource == null)
    {
        return "";
    }

    return resources::shader::get_code(resource)!!;
}

fn usz shader_get_code_size(Resource* resource) @export("shader_get_code_size") @wasm @if($feature(PLATFORM_WEB))
{
    if (resource == null)
    {
        return 0;
    }

    String code = resources::shader::get_code(resource)!!;
    return code.len;
}

fn char* shader_get_entry(Resource* resource, SupportedShaderStage stage) @export("shader_get_entry") @wasm @if($feature(PLATFORM_WEB))
{
    if (resource == null)
    {
        return null;
    }

    return resources::shader::get_entry(resource, stage);
}

fn usz shader_get_entry_size(Resource* resource, SupportedShaderStage stage) @export("shader_get_entry_size") @wasm @if($feature(PLATFORM_WEB))
{
    if (resource == null)
    {
        return 0;
    }

    String entry = resources::shader::get_entry(resource, stage);
    return entry.len;
}

// Memory

fn void* wasm_allocate(usz size) @wasm @export("allocate") @if($feature(PLATFORM_WEB))
{
    return allocator::temp().acquire(size, AllocInitType.ZERO, 0)!!;
}

fn void wasm_submit_gpu_memory_allocation(usz size, GPUMemoryTag tag) @wasm @export("submit_gpu_memory_allocation") @if($feature(PLATFORM_WEB))
{
    memory::submit_gpu_memory_allocation(size, tag);
}

fn void wasm_submit_gpu_memory_deallocation(usz size, GPUMemoryTag tag) @wasm @export("submit_gpu_memory_deallocation") @if($feature(PLATFORM_WEB))
{
    memory::submit_gpu_memory_deallocation(size, tag);
}

fn void wasm_log_memory_report() @wasm @export("log_memory_report") @if($feature(PLATFORM_WEB))
{
    memory::log_memory_report()!!;
}

// Vertex Layout

fn usz vertex2d_get_size() @wasm @export("vertex2d_get_size") @if($feature(PLATFORM_WEB))
{
    return Vertex2d.sizeof;
}

fn usz vertex3d_get_size() @wasm @export("vertex3d_get_size") @if($feature(PLATFORM_WEB))
{
    return Vertex3d.sizeof;
}

fn usz vertex2d_get_attribute_count() @wasm @export("vertex2d_get_attribute_count") @if($feature(PLATFORM_WEB))
{
    return math::vertex2d_attribute_count();
}

fn usz vertex3d_get_attribute_count() @wasm @export("vertex3d_get_attribute_count") @if($feature(PLATFORM_WEB))
{
    return math::vertex3d_attribute_count();
}

fn usz vertex2d_get_attribute_offset(usz index) @wasm @export("vertex2d_get_attribute_offset") @if($feature(PLATFORM_WEB))
{
    return math::vertex2d_attribute_offset(index);
}

fn usz vertex3d_get_attribute_offset(usz index) @wasm @export("vertex3d_get_attribute_offset") @if($feature(PLATFORM_WEB))
{
    return math::vertex3d_attribute_offset(index);
}

fn usz vertex2d_get_attribute_format(usz index) @wasm @export("vertex2d_get_attribute_format") @if($feature(PLATFORM_WEB))
{
    return (usz) math::vertex2d_attribute_format(index);
}

fn usz vertex3d_get_attribute_format(usz index) @wasm @export("vertex3d_get_attribute_format") @if($feature(PLATFORM_WEB))
{
    return (usz) math::vertex3d_attribute_format(index);
}