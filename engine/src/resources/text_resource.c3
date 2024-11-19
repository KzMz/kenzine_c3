module kenzine::resources;

import kenzine::memory;
import kenzine::resource;
import kenzine::faults;
import std::io::path;
import std::io::file;

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

    File file = io::file::open(path.path_string, "r")!;
    defer file.close()!!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = memory::MemoryTag.TEXT;
    out_resource.path = path.path_string.copy(memory::kallocator());
    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

    out_resource.size = io::file::get_size(path.path_string)!;

    char[] buffer = memory::kallocate_many(char, out_resource.size, MemoryTag.TEXT);
    out_resource.data = io::file::load_buffer(path.path_string, buffer)!;

    out_resource.size = out_resource.data.len;
}

fn void! TextResourceLoaderFunctions.unload(TextResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    unload_resource(resource, MemoryTag.TEXT)!;
}

TextResourceLoaderFunctions loader_functions;

fn ResourceLoader text_resource_loader()
{
    ResourceLoader loader;
    loader.type = ResourceType.TEXT;
    loader.custom_type = "";
    loader.type_path = "";
    loader.functions = (ResourceLoaderFunctions) &loader_functions;
    return loader;
}