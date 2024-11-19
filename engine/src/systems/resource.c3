module kenzine::resource;

import kenzine::resources;
import kenzine::core;
import kenzine::memory;
import kenzine::faults;
import kenzine::app;
import kenzine::log;
import kenzine::utils;
import std::collections::list;

struct ResourceState
{
    ResourceParams config;
    List(<ResourceLoader>) resource_loaders; // See if it is good to be used like this or if we want just a decayed array
}

struct ResourceParams
{
    int max_loaders;
    String base_asset_path;
}

def CoreSystem = kenzine::core::System(<ResourceState, ResourceParams>);
struct ResourceSystem(CoreSystem)
{
    ResourceState* state;
}

ResourceState* resource_state = null;

fn void! ResourceSystem.initialize(ResourceSystem* self, ResourceState* state, ResourceParams* params) @dynamic
{
    resource_state = state;

    self.state = state;
    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    if (params.base_asset_path.len == 0)
    {
        return ResourceSystemError.BASE_ASSET_PATH_EMPTY?;
    }

    self.state.config = *params;
    self.state.resource_loaders.new_init(params.max_loaders, memory::kallocator());

    self.register_default_loaders()!;
}

fn void! ResourceSystem.shutdown(ResourceSystem* self) @dynamic
{
    self.state.resource_loaders.free();
}

fn void! ResourceSystem.register_default_loaders(ResourceSystem* self)
{
    self.register_loader(resources::text_resource_loader())!;
    self.register_loader(resources::shader_resource_loader())!;
}

fn void! ResourceSystem.register_loader(ResourceSystem* self, ResourceLoader loader)
{
    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (loader.type == ResourceType.UNKNOWN)
    {
        return ResourceSystemError.RESOURCE_LOADER_INVALID_TYPE?;
    }

    if (get_loader(loader.type, loader.custom_type)! != null)
    {
        return ResourceSystemError.RESOURCE_LOADER_ALREADY_REGISTERED?;
    }

    if (self.state.resource_loaders.len() >= self.state.config.max_loaders)
    {
        return ResourceSystemError.RESOURCE_LOADERS_LIMIT_REACHED?;
    }

    self.state.resource_loaders.push(loader);
}

fn void! load(ResourceType type, String name, Resource* out_resource)
{
    if (resource_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (type == ResourceType.UNKNOWN)
    {
        return ResourceSystemError.RESOURCE_LOADER_INVALID_TYPE?;
    }

    if (type == ResourceType.CUSTOM)
    {
        return ResourceSystemError.RESOURCE_LOADER_USE_LOAD_CUSTOM_INSTEAD?;
    }

    ResourceLoader* loader = get_loader(type, "")!;
    if (loader == null)
    {
        return ResourceSystemError.RESOURCE_LOADER_NOT_FOUND?;
    }

    loader.functions.load(loader, name, out_resource)!;
}

fn void! ResourceSystem.load(ResourceSystem* self, ResourceType type, String name, Resource* out_resource)
{
    load(type, name, out_resource)!;
}

fn void! load_custom(String custom_type, String name, Resource* out_resource)
{
    if (resource_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (custom_type.len == 0)
    {
        return ResourceSystemError.RESOURCE_LOADER_INVALID_TYPE?;
    }

    ResourceLoader* loader = get_loader(ResourceType.CUSTOM, custom_type)!;
    if (loader == null)
    {
        return ResourceSystemError.RESOURCE_LOADER_NOT_FOUND?;
    }

    loader.functions.load(loader, name, out_resource)!;
}

fn void! ResourceSystem.load_custom(ResourceSystem* self, String custom_type, String name, Resource* out_resource)
{
    load_custom(custom_type, name, out_resource)!;
}

fn void! unload(Resource* resource)
{
    if (resource_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    ResourceLoader* loader = get_loader(resource.type, resource.metadata.custom_type)!;
    if (loader == null)
    {
        return ResourceSystemError.RESOURCE_LOADER_NOT_FOUND?;
    }

    loader.functions.unload(loader, resource)!;
}

fn void! ResourceSystem.unload(ResourceSystem* self, Resource* resource)
{
    unload(resource)!;
}

fn ResourceLoader*! get_loader(ResourceType type, String custom_type)
{
    if (resource_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    for (usz i = 0; i < resource_state.resource_loaders.len(); i++)
    {
        if (resource_state.resource_loaders[i].type != type)
        {
            continue;
        }

        if (type == ResourceType.CUSTOM)
        {
            if (resource_state.resource_loaders[i].custom_type != custom_type)
            {
                continue;
            }
        }

        return &resource_state.resource_loaders[i];
    }

    return null;
}

fn String! get_base_asset_path()
{
    if (resource_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    return resource_state.config.base_asset_path;
}