module kenzine::resources;

import kenzine::memory;
import kenzine::resource;
import kenzine::faults;
import kenzine::renderer;
import kenzine::utils;
import std::io::path;
import std::io::file;
import std::collections::list;
import std::collections::object;
import std::encoding::json;

struct ShaderStageData
{
    SupportedShaderStage stage;
    String entry;
    String source;
}

struct ShaderData
{
    String renderpass;
    String shader_file;
    String vertex_type;
    SupportedShaderFormat shader_format;

    List(<ShaderStageData>) stages;
}

struct ShaderResourceLoaderFunctions(ResourceLoaderFunctions)
{
    bool pad;
}

fn void! ShaderResourceLoaderFunctions.load(ShaderResourceLoaderFunctions* self, ResourceLoader* loader, String name, Resource* out_resource) @dynamic
{
    Path path = path::temp_new(resource::get_base_asset_path()!)!;

    DString descriptor_file = dstring::temp_new(name);
    descriptor_file.append(loader.type.extensions[0]);

    path = path.new_append(loader.type_path)!;
    path = path.new_append(descriptor_file.str_view())!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = resources::get_memory_tag(loader.type);
    out_resource.path = path.path_string.copy(memory::kallocator());

    char[] buffer = resources::get_resource_file_contents(path.path_string, loader.type)!;

    Object* json = json::temp_parse_string((String) buffer)!;
    out_resource.metadata = get_resource_metadata_checked(json, loader.type)!;

    ShaderData* data = memory::kallocate(ShaderData, resources::get_memory_tag(loader.type))!;
    data.renderpass = json.get_string("renderpass")!;//.copy(memory::kallocator());
    data.shader_format = renderer::format_from_string(json.get_string("format")!);
    data.shader_file = json.get_string("shader_file")!;//.copy(memory::kallocator());
    data.vertex_type = json.get_string("vertex_type")!;//.copy(memory::kallocator());

    Object* stages = json.get("stages")!;
    usz count = stages.get_len();

    for (usz i = 0; i < count; i++)
    {
        Object* stage = stages.get_at(i);
        ShaderStageData stage_data;
        stage_data.stage = renderer::stage_from_string(stage.get_string("stage")!);
        stage_data.entry = stage.get_string("entry")!;//.copy(memory::kallocator());

        String! source = stage.get_string("source");
        if (try source)
        {   
            stage_data.source = source;//source.copy(memory::kallocator());
        }

        data.stages.push(stage_data);
    }

    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

    out_resource.data = utils::ptr_to_slice(ShaderData, char, data);
    out_resource.size = ShaderData.sizeof;
}

fn void! ShaderResourceLoaderFunctions.unload(ShaderResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    ShaderData* data = utils::slice_to_ptr(ShaderData, resource.data);
    data.stages.clear();

    unload_resource(resource, resources::get_memory_tag(loader.type))!;
}

ShaderResourceLoaderFunctions shader_loader_functions;

fn ResourceLoader shader_resource_loader()
{
    ResourceLoader loader;
    loader.type = ResourceType.SHADER;
    loader.custom_type = "";
    loader.type_path = "shaders";
    loader.functions = (ResourceLoaderFunctions) &shader_loader_functions;
    return loader;
}

module kenzine::resources::shader;

import kenzine::memory;
import kenzine::resource;
import kenzine::faults;
import kenzine::renderer;
import kenzine::utils;
import std::io::path;
import std::io::file;
import std::collections::list;
import std::collections::object;
import std::encoding::json;

fn String get_entry(Resource* resource, SupportedShaderStage stage)
{
    ShaderData* data = utils::slice_to_ptr(ShaderData, resource.data);

    for (usz i = 0; i < data.stages.len(); i++)
    {
        if (data.stages[i].stage == stage)
        {
            return data.stages[i].entry;
        }
    }

    return "";
}

fn String get_vertex_type(Resource* resource)
{
    ShaderData* data = utils::slice_to_ptr(ShaderData, resource.data);
    return data.vertex_type;
}

// TODO: support for different formats and stages. Webgpu just has everything put inside the same file
fn String! get_code(Resource* resource)
{
    if (resource.type != ResourceType.SHADER)
    {
        return ResourceSystemError.RESOURCE_INVALID_TYPE?;
    }

    ResourceLoader* loader = resource::get_loader(resource.type, resource.metadata.custom_type)!;

    ShaderData* data = utils::slice_to_ptr(ShaderData, resource.data);

    Path path = path::temp_new(resource::get_base_asset_path()!)!;
    DString descriptor_file = dstring::temp_new(data.shader_file);

    if (!descriptor_file.str_view().ends_with(data.shader_format.extension))
    {
        descriptor_file.append(data.shader_format.extension);
    }

    path = path.new_append(loader.type_path)!;
    path = path.new_append(descriptor_file.str_view())!;

    char[] buffer = resources::get_resource_file_contents(path.path_string, loader.type)!;
    return ((String) buffer);//.copy(memory::kallocator());
}