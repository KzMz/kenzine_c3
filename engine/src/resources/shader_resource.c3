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
    SupportedShaderStages stage;
    String entry;
    String source;
}

struct ShaderData
{
    String renderpass;
    String shader_file;

    List(<ShaderStageData>) stages;
}

struct ShaderResourceLoaderFunctions(ResourceLoaderFunctions)
{
    bool pad;
}

fn void! ShaderResourceLoaderFunctions.load(ShaderResourceLoaderFunctions* self, ResourceLoader* loader, String name, Resource* out_resource) @dynamic
{
    Path path = path::temp_new(resource::get_base_asset_path()!)!;
    defer path.free();

    DString descriptor_file = dstring::temp_new(name);
    defer descriptor_file.free();

    descriptor_file.append(ResourceType.SHADER.extensions[0]);

    path = path.new_append(loader.type_path)!;
    path = path.new_append(descriptor_file.str_view())!;

    File file = io::file::open(path.path_string, "r")!;
    defer file.close()!!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = memory::MemoryTag.SHADER;
    out_resource.path = path.path_string.copy(memory::kallocator());

    out_resource.size = io::file::get_size(path.path_string)!;

    char[] buffer = memory::kallocate_many(char, out_resource.size, MemoryTag.SHADER);
    io::file::load_buffer(path.path_string, buffer)!;

    Object* json = json::temp_parse_string((String) buffer[3..])!;
    out_resource.metadata = get_resource_metadata_checked(json, loader.type)!;

    ShaderData* data = memory::kallocate(ShaderData, MemoryTag.SHADER)!;
    data.renderpass = json.get_string("renderpass")!.copy(memory::kallocator());
    data.shader_file = json.get_string("shader_file")!.copy(memory::kallocator());

    Object* stages = json.get("stages")!;
    usz count = stages.get_len();

    for (usz i = 0; i < count; i++)
    {
        Object* stage = stages.get_at(i);
        ShaderStageData stage_data;
        stage_data.stage = renderer::stage_from_string(stage.get_string("stage")!);
        stage_data.entry = stage.get_string("entry")!.copy(memory::kallocator());

        String source = stage.get_string("source")!;
        stage_data.source = source.copy(memory::kallocator());

        data.stages.push(stage_data);
    }

    // TODO: fill the data

    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

    out_resource.data = utils::ptr_to_slice(ShaderData, char, data);
}

fn void! ShaderResourceLoaderFunctions.unload(ShaderResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    ShaderData* data = utils::slice_to_ptr(ShaderData, resource.data);
    data.stages.clear();

    unload_resource(resource, MemoryTag.SHADER)!;
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