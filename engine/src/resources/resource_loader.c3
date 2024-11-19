module kenzine::resources;

import kenzine::memory;

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