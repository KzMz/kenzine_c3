module kenzine::resources;

import kenzine::math;
import kenzine::utils;
import kenzine::memory;
import kenzine::resource;

import std::collections::object;
import std::collections::list;
import std::encoding::json;
import std::io::path;
import std::math::vector;

// temp
import kenzine::log;
// temp

struct GeometryData
{
    ulong resource_id;
    String vertex_type;
    List(<Vertex2d>) vertices_2d;
    List(<Vertex3d>) vertices_3d;
    List(<Index>) indices;
}

struct GeometryResourceLoaderFunctions(ResourceLoaderFunctions)
{
    bool pad;
}

fn void! GeometryResourceLoaderFunctions.load(GeometryResourceLoaderFunctions* self, ResourceLoader* loader, String name, Resource* out_resource) @dynamic
{
    Path path = path::temp_new(resource::get_base_asset_path()!)!;

    DString descriptor_file = dstring::temp_new(name);
    descriptor_file.append(loader.type.extensions[0]);

    path = path.new_append(loader.type_path)!;
    path = path.new_append(descriptor_file.str_view())!;

    out_resource.type = loader.type;
    out_resource.name = name;

    memory::kenzine_allocator.current_tag = resources::get_memory_tag(loader.type);
    out_resource.path = path.path_string.copy(memory::kallocator());

    char[] buffer = resources::get_resource_file_contents(path.path_string, loader.type)!;

    Object* json = json::temp_parse_string((String) buffer)!;
    out_resource.metadata = get_resource_metadata_checked(json, loader.type)!;

    GeometryData* data = memory::kallocate(GeometryData, resources::get_memory_tag(loader.type))!;
    data.vertex_type = json.get_string("vertex_type")!;

    Object* vertices = json.get("vertices")!;
    for (usz i = 0; i < vertices.get_len(); ++i)
    {
        Object* vertex = vertices.get_at(i);
        if (data.vertex_type == "vertex2d") // TODO: replace this with a constant or enum
        {
            Vertex2d v;

            Object* position = vertex.get("position")!;
            v.position = { (float) position.get_float_at(0)!, (float) position.get_float_at(1)! };

            Object* color = vertex.get("color")!;
            v.color = { (float) color.get_float_at(0)!, (float) color.get_float_at(1)!, (float) color.get_float_at(2)!, (float) color.get_float_at(3)! };

            //v.uv = math::vec2(vertex.get_vec2("uv")!);
            data.vertices_2d.push(v);
        }
        else if (data.vertex_type == "vertex3d")
        {
            Vertex3d v;

            Object* position = vertex.get("position")!;
            v.position = { (float) position.get_float_at(0)!, (float) position.get_float_at(1)!, (float) position.get_float_at(2)! };

            Object* color = vertex.get("color")!;
            v.color = { (float) color.get_float_at(0)!, (float) color.get_float_at(1)!, (float) color.get_float_at(2)!, (float) color.get_float_at(3)! };

            //v.uv = math::vec2(vertex.get_vec2("uv")!);
            data.vertices_3d.push(v);
        }
    }

    Object* indices = json.get("indices")!;
    for (usz i = 0; i < indices.get_len(); ++i)
    {
        data.indices.push((Index) indices.get_uint_at(i))!;
    }

    memory::kenzine_allocator.current_tag = memory::MemoryTag.CUSTOM;

    out_resource.id = cache::get_id(descriptor_file.str_view());
    data.resource_id = out_resource.id;
    out_resource.data = utils::ptr_to_slice(GeometryData, char, data);
    out_resource.size = GeometryData.sizeof; // TODO: add this to the finalize resource?
}

fn void! GeometryResourceLoaderFunctions.unload(GeometryResourceLoaderFunctions* self, ResourceLoader* loader, Resource* resource) @dynamic
{
    GeometryData* data = utils::slice_to_ptr(GeometryData, resource.data);
    data.vertices_2d.clear();
    data.vertices_3d.clear();
    data.indices.clear();

    unload_resource(resource, resources::get_memory_tag(loader.type))!;
}

GeometryResourceLoaderFunctions geometry_loader_functions;

fn ResourceLoader geometry_resource_loader()
{
    ResourceLoader loader;
    loader.type = ResourceType.GEOMETRY;
    loader.custom_type = "";
    loader.type_path = "geometries";
    loader.functions = (ResourceLoaderFunctions) &geometry_loader_functions;
    return loader;
}