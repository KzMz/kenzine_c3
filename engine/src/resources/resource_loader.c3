module kenzine::resources;

import kenzine::memory;
import kenzine::faults;
import std::collections::object;

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