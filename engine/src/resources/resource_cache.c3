module kenzine::resources::cache;

import kenzine::resources;
import kenzine::memory;
import kenzine::faults;

import std::io;

const usz MAX_LOADED_RESOURCES = 1024;
const String INVALID_RESOURCE_NAME = "";
const char[] INVALID_RESOURCE_DATA = "";
const usz INVALID_RESOURCE_ID = usz.max;

struct ResourceCache
{
    String[MAX_LOADED_RESOURCES] resource_names;
    char[][MAX_LOADED_RESOURCES] resource_data;
}

ResourceCache resource_cache @private;

fn void! add(String resource_name, char[] resource_data)
{
    usz index = find_empty_index();
    if (index == INVALID_RESOURCE_ID)
    {
        return ResourceSystemError.RESOURCE_CACHE_FULL?;
    }

    resource_cache.resource_names[index] = resource_name;
    resource_cache.resource_data[index] = resource_data;
}

fn char[]! get(String resource_name)
{
    char[] data = find_resource_data(resource_name);
    if (data == INVALID_RESOURCE_DATA)
    {
        return ResourceSystemError.RESOURCE_NOT_FOUND_OR_INVALID?;
    }

    return data;
}

fn void remove(String resource_name)
{
    usz index = find_resource_index(resource_name);
    if (index == INVALID_RESOURCE_ID)
    {
        return; // No error here
    }

    resource_cache.resource_names[index] = INVALID_RESOURCE_NAME;
    resource_cache.resource_data[index] = INVALID_RESOURCE_DATA;
}

fn usz find_resource_index(String resource_name) @private
{
    if (resource_name == INVALID_RESOURCE_NAME)
    {
        return INVALID_RESOURCE_ID;
    }

    for (usz i = 0; i < MAX_LOADED_RESOURCES; i++)
    {
        if (resource_cache.resource_names[i] == INVALID_RESOURCE_NAME) continue;

        if (resource_cache.resource_names[i] == resource_name)
        {
            return i;
        }
    }

    return INVALID_RESOURCE_ID;
}

fn usz find_empty_index() @private
{
    for (usz i = 0; i < MAX_LOADED_RESOURCES; i++)
    {
        if (resource_cache.resource_names[i] == INVALID_RESOURCE_NAME)
        {
            return i;
        }
    }

    return INVALID_RESOURCE_ID;
}

fn char[] find_resource_data(String resource_name) @private
{
    if (resource_name == INVALID_RESOURCE_NAME)
    {
        return INVALID_RESOURCE_DATA;
    }

    usz index = find_resource_index(resource_name);
    if (index == INVALID_RESOURCE_ID)
    {
        return INVALID_RESOURCE_DATA;
    }

    return resource_cache.resource_data[index];
}