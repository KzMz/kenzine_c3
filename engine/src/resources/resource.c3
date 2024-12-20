module kenzine::resources;

import kenzine::memory;
import kenzine::utils;

// TODO: multiple extensions per type
enum ResourceType : int(String[] extensions, String json_type)
{
    UNKNOWN = { {""}, "" },
    TEXT = { {""}, "" },
    BINARY = { {""}, "" },
    IMAGE = { {".png", ".jpg", ".jpeg", ".bmp", ".tga"}, "" },
    SHADER = { {".shader.json"}, "shader" },
    GEOMETRY = { {".geom.json"}, "geometry" },
    CUSTOM = { {""}, "" },
}

struct ResourceMetadata
{
    String version;
    String custom_type;
    bool embedded;
}

struct Resource
{
    usz id;
    ResourceType type;
    String name;
    String path;

    ResourceMetadata metadata;

    usz size;
    char[] data;
}

fn String Resource.as_string(Resource* self)
{
    if (self.data.len <= 3)
    {
        return "";
    }

    return (String) self.data;
}

fn Resource* new(String resource_name, ResourceType type)
{
    if (type == ResourceType.UNKNOWN)
    {
        return null;
    }

    if (resource_name.len == 0)
    {
        return null;
    }

    Resource* resource = memory::kallocate(Resource, get_memory_tag(type))!!;
    resource.type = type;
    resource.name = resource_name;
    resource.id = usz.max;

    return resource;
}

macro get_resource_data(Resource* resource, $Type)
{
    return utils::slice_to_ptr($Type, resource.data);
}

macro get_resource_data_by_id(ulong resource_id, $Type)
{
    char[] data = cache::get_by_id(resource_id)!;
    return utils::slice_to_ptr($Type, data);
}

macro get_resource_data_flat(Resource* resource, $Type)
{
    $Type* copy_ptr = utils::slice_to_ptr($Type, resource.data);
    return *copy_ptr;
}