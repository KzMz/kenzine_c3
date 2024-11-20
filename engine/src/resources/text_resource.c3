module kenzine::resources;

import kenzine::memory;
import kenzine::resource;
import kenzine::faults;
import kenzine::platform::wasm;
import kenzine::utils;
import std::io::path;

import kenzine::log;

struct TextResourceLoaderFunctions(ResourceLoaderFunctions)
{
    bool pad;
}

fn void! TextResourceLoaderFunctions.load(TextResourceLoaderFunctions* self, ResourceLoader* loader, String name, Resource* out_resource) @dynamic
{
    Path path = path::temp_new(resource::get_base_asset_path()!)!;

    path = path.new_append(loader.type_path)!;
    path = path.new_append(name)!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = resources::get_memory_tag(loader.type);
    out_resource.path = path.path_string.copy(memory::kallocator());
    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

    out_resource.data = resources::get_resource_file_contents(path.path_string, loader.type)!;
    out_resource.size = out_resource.data.len;
}

// TODO: move it somewhere else and see if this is needed at all
fn void! on_resource_loaded(char* buffer, usz buffer_len) @wasm @export("on_resource_loaded") @if($feature(PLATFORM_WEB))
{
    log::log(LogLevel.INFO, "Resource loaded of size %d - contents: \n%s", buffer_len, (String) buffer[3..buffer_len-1])!;
}

fn void! TextResourceLoaderFunctions.unload(TextResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    unload_resource(resource, resources::get_memory_tag(loader.type))!;
}

TextResourceLoaderFunctions text_loader_functions @private;

fn ResourceLoader text_resource_loader()
{
    ResourceLoader loader;
    loader.type = ResourceType.TEXT;
    loader.custom_type = "";
    loader.type_path = "";
    loader.functions = (ResourceLoaderFunctions) &text_loader_functions;
    return loader;
}