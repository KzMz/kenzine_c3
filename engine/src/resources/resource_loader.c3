module kenzine::resources;

import kenzine::log;
import kenzine::memory;
import kenzine::faults;
import std::collections::object;
import std::io::file;
import std::io::path;

interface ResourceLoaderFunctions
{
    fn void! load(ResourceLoader* loader, String name, Resource* out_resource);
    fn void! unload(ResourceLoader* loader, Resource* resource);
}

struct ResourceLoader
{
    ResourceType type;
    String custom_type;
    String type_path;

    ResourceLoaderFunctions functions;
}

fn void! unload_resource(Resource* resource, MemoryTag tag)
{
    if (resource.data.len > 0)
    {
        memory::free(&resource.data[0], resource.data.len, tag)!;
    }
}

fn ResourceMetadata! get_resource_metadata_checked(Object* json, ResourceType type)
{
    ResourceMetadata metadata = { .version = "", .custom_type = "" };
    Object* resource_metadata = json.get("resource")!;
    if (resource_metadata != null)
    {
        metadata.version = resource_metadata.get_string("version")!;
        String json_type = resource_metadata.get_string("type")!;

        if (json_type != type.json_type)
        {
            return ResourceSystemError.RESOURCE_TYPE_MISMATCH?;
        }

        bool! embedded = resource_metadata.get_bool("embedded");
        if (try embedded)
        {
            metadata.embedded = embedded;
        }
        else
        {
            metadata.embedded = false;
        }

        String! custom_type = resource_metadata.get_string("custom_type");
        if (try custom_type)
        {
            metadata.custom_type = custom_type.copy();
        }
    }

    return metadata;
}

fn MemoryTag get_memory_tag(ResourceType type)
{
    switch (type)
    {
        case ResourceType.TEXT:
            return MemoryTag.TEXT;
        case ResourceType.SHADER:
            return MemoryTag.SHADER;
        case ResourceType.IMAGE:
            return MemoryTag.TEXTURE;
        case ResourceType.GEOMETRY:
            return MemoryTag.GEOMETRY;
        case ResourceType.CUSTOM:
            return MemoryTag.CUSTOM;
        default:
            return MemoryTag.NONE;
    }
}

fn char[]! get_resource_file_contents(String path, ResourceType type)
{
    DString cache_key = dstring::temp_new(path);
    cache_key.replace("\\", "_");
    cache_key.replace("/", "_");

$if(!$feature(PLATFORM_WEB)):
    char[]! cached = cache::get(cache_key.str_view());
    
    if (try cached)
    {
        //log::log(LogLevel.INFO, "Loading resource %s from cache", path)!;
        return cached;
    }

    File file = io::file::open(path, "r")!;
    defer file.close()!!;

    usz size = io::file::get_size(path)!;
    char[] buffer = memory::kallocate_many(char, size + 1, get_memory_tag(type));

    Path p = path::temp_new(path)!;
    cache::add(cache_key.str_view(), p.basename(), buffer)!;

    io::file::load_buffer(path, buffer)!;
    buffer[size] = 0;

    log::log(LogLevel.INFO, "Loaded resource %s of size %d", path, size)!;
    return buffer[3..]; // for some reason I have some garbage data at the beginning of the buffer, chop it
$else
    return cache::get(cache_key.str_view())!;
$endif
}