module kenzine::resources;

import kenzine::memory;
import kenzine::resource;
import kenzine::faults;
import kenzine::platform::wasm;
import kenzine::utils;
import std::io::path;
import std::io::file;

import kenzine::log;

struct TextResourceLoaderFunctions(ResourceLoaderFunctions)
{
    bool pad;
}

fn void! TextResourceLoaderFunctions.load(TextResourceLoaderFunctions* self, ResourceLoader* loader, String name, Resource* out_resource) @dynamic
{
    Path path = path::temp_new(resource::get_base_asset_path()!)!;
    defer path.free();

    path = path.new_append(loader.type_path)!;
    path = path.new_append(name)!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = memory::MemoryTag.TEXT;
    out_resource.path = path.path_string.copy(memory::kallocator());
    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

$if($feature(PLATFORM_WEB)):
    wasm::wasm_load_resource(path.path_string, path.path_string.len);
$else
    File file = io::file::open(path.path_string, "r")!;
    defer file.close()!!;

    out_resource.size = io::file::get_size(path.path_string)!;

    char[] buffer = memory::kallocate_many(char, out_resource.size, MemoryTag.TEXT);
    out_resource.data = io::file::load_buffer(path.path_string, buffer)!;
$endif
}

// TODO: move it somewhere else and see if this is needed at all
fn void! on_resource_loaded(char* buffer, usz buffer_len) @wasm @export("on_resource_loaded") @if($feature(PLATFORM_WEB))
{
    log::log(LogLevel.INFO, "Resource loaded of size %d - contents: \n%s", buffer_len, (String) buffer[3..buffer_len-1])!;
}

fn void! TextResourceLoaderFunctions.unload(TextResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    unload_resource(resource, MemoryTag.TEXT)!;
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