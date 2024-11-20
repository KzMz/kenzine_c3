module kenzine::resources::cache;

import kenzine::resources;
import kenzine::memory;
import std::collections::map;

struct ResourceCache
{
    HashMap(<String, char[]>) resource_data;
}

ResourceCache resource_cache @private;

fn void initialize()
{
    uint capacity = map::DEFAULT_INITIAL_CAPACITY(<String, char[]>);
    float load_factor = map::DEFAULT_LOAD_FACTOR(<String, char[]>);
    resource_cache.resource_data.new_init(capacity, load_factor, memory::kallocator());
}

fn void add(String resource_name, char[] resource_data)
{
    if (resource_cache.resource_data.has_key(resource_name))
    {
        return;
    }

    resource_cache.resource_data.set(resource_name, resource_data);
}

fn char[]! get(String resource_name)
{
    return resource_cache.resource_data.get(resource_name);
}

fn void remove(String resource_name)
{
    if (!resource_cache.resource_data.has_key(resource_name))
    {
        return;
    }

    resource_cache.resource_data.remove(resource_name);
}

fn void shutdown()
{
    resource_cache.resource_data.free();
}