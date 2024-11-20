module kenzine::resources;

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

    return (String) self.data[3..]; // for some reason I have some garbage data at the beginning of the buffer, chop it
}