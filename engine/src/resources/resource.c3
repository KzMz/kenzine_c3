module kenzine::resources;

import kenzine::memory;

// TODO: multiple extensions per type
enum ResourceType : int(String[] extensions, String json_type)
{
    UNKNOWN = { {""}, "" },
    TEXT = { {""}, "" },
    BINARY = { {""}, "" },
    IMAGE = { {".png", ".jpg", ".jpeg", ".bmp", ".tga"}, "" },
    SHADER = { {".shader.json"}, "shader" },
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

    return resource;
}