module kenzine::resources;

import kenzine::log;
import kenzine::memory;
import kenzine::faults;
import std::collections::object;
import std::io::file;

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

        //metadata.custom_type = resource_metadata.get("custom_type")?.to_string()!;
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
        case ResourceType.CUSTOM:
            return MemoryTag.CUSTOM;
        default:
            return MemoryTag.NONE;
    }
}

fn char[]! get_resource_file_contents(String path, ResourceType type)
{
    char[]! cached = cache::get(path);
    if (try cached)
    {
        return cached;
    }

$if(!$feature(PLATFORM_WEB)):
    File file = io::file::open(path, "r")!;
    defer file.close()!!;

    usz size = io::file::get_size(path)!;
    char[] buffer = memory::kallocate_many(char, size, get_memory_tag(type));
    cache::add(path, buffer);

    io::file::load_buffer(path, buffer)!;

    log::log(LogLevel.INFO, "Loaded resource %s of size %d", path, size)!;
    return buffer[3..]; // for some reason I have some garbage data at the beginning of the buffer, chop it
$else
    return null;
$endif
}