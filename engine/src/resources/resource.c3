module kenzine::resources;

enum ResourceType
{
    UNKNOWN,
    TEXT,
    BINARY,
    IMAGE,
    SHADER,
    CUSTOM
}

struct ResourceMetadata
{
    String custom_type;
    String version;
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
    return (String) self.data[3..]; // for some reason I have some garbage data at the beginning of the buffer, chop it
}