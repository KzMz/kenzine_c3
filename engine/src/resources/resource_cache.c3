module kenzine::resources::cache;

import kenzine::resources;
import kenzine::memory;
import kenzine::faults;

import std::io;
import std::collections::map;

const usz MAX_LOADED_RESOURCES = 1024;
const String INVALID_RESOURCE_NAME = "";
const char[] INVALID_RESOURCE_DATA = "";
const usz INVALID_RESOURCE_ID = usz.max;

struct ResourceCache
{
    String[MAX_LOADED_RESOURCES] resource_names;
    char[][MAX_LOADED_RESOURCES] resource_data;

    // TODO: search for duplicates here
    HashMap(<String, usz>) friendly_name_to_id;
}

ResourceCache resource_cache @private;

fn void! add(String resource_name, String friendly_name, char[] resource_data)
{
    usz index = find_empty_index();
    if (index == INVALID_RESOURCE_ID)
    {
        return ResourceSystemError.RESOURCE_CACHE_FULL?;
    }

    resource_cache.resource_names[index] = resource_name;
    resource_cache.resource_data[index] = resource_data;

    if (friendly_name != INVALID_RESOURCE_NAME)
    {
        resource_cache.friendly_name_to_id.set(friendly_name, index);
    }
}

fn usz get_id(String friendly_name)
{
    return resource_cache.friendly_name_to_id.get(friendly_name)!!;
}

fn char[]! get_by_friendly_name(String friendly_name)
{
    usz index = resource_cache.friendly_name_to_id.get(friendly_name)!!;
    String resource_name = resource_cache.resource_names[index];
    return get(resource_name);
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

fn char[]! get_by_id(ulong resource_id)
{
    if (resource_id >= MAX_LOADED_RESOURCES)
    {
        return ResourceSystemError.RESOURCE_NOT_FOUND_OR_INVALID?;
    }

    return resource_cache.resource_data[resource_id];
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

fn usz find_resource_index(String resource_name)
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