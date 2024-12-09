import std::io;
import std::io::file;
import std::io::path;
import std::hash::md5;
import std::collections::object;
import std::encoding::json;
import std::collections::list;

Path src_path;
Path dst_path;

usz asset_index = 0;

const bool FORCE_EMBED = true;
List(<Path>) already_embedded;

fn bool should_be_embedded(String extension, bool force)
{
    if (force) return true;
    if (extension != "json" && extension != "txt") return false;

    return true;
}

fn bool! walk_asset(Path path, bool is_dir, void* data)
{
    if (is_dir) return false;
    if (path.path_string.contains("embeds")) return false;
    if (already_embedded.contains(path)) return false;

    bool force = false;
    if (data != null)
    {
        force = *(bool*) data;
    }
    if (try String extension = path.extension())
    {
        if (!should_be_embedded(extension, force))
        {
            io::printfn("Skipping asset: %s", path.path_string)!;
            return false;
        }
    }

    usz size = io::file::get_size(path.path_string)!;
    char[] buffer = allocator::new_array(allocator::heap(), char, size);
    buffer = io::file::load_buffer(path.path_string, buffer)!;
    buffer = buffer[3..];

    if (try String extension = path.extension())
    {
        if (extension == "json")
        {
            Object* json = json::temp_parse_string((String) buffer)!;
            Object* resource_metadata = json.get("resource")!;
            if (resource_metadata != null)
            {
                bool embedded = resource_metadata.get_bool("embedded")!;
                if (!embedded)
                {
                    io::printfn("Skipping embedded asset: %s", path.path_string)!;
                    return false;
                }
            }

            Object* dependencies = resource_metadata.get("dependencies")!;
            if (dependencies != null)
            {
                for (usz i = 0; i < dependencies.get_len(); i++)
                {
                    String dependency = dependencies.get_string_at(i)!;
                    Path dep_path = path.parent().new_append(dependency)!;

                    io::printfn("Embedding dependency: %s", dep_path.path_string)!;
                    walk_asset(dep_path, false, &FORCE_EMBED)!;
                }
            }
        }
    }

    DString c3_name = dstring::temp_new(path.basename());
    c3_name.append(".c3");

    Path dst = dst_path.new_append(c3_name.str_view())!;

    io::printfn("Embedding asset: %s in %s", path.path_string, dst.path_string)!;

    DString c3_data = dstring::temp_new("module kenzine::assets;\n\n");
    c3_data.append("import kenzine::resources::cache;\n");
    c3_data.append("import std::io;\n\n");

    c3_data.appendf("String asset_data_%d = `%s`;\n\n", asset_index, (String) buffer)!;

    Splitter splitter = path.path_string.splitter("assets");
    String split = splitter.next()!;
    split = splitter.next()!;

    DString escaped_string = dstring::temp_new(split);
    escaped_string.replace("\\", "_");

    c3_data.appendf("fn void embed_asset_%d() @init(1024)\n", asset_index)!;
    c3_data.append("{\n");

    c3_data.appendf("\tcache::add(\"%s_%s\", asset_data_%d)!!;\n", "assets", escaped_string.str_view()[1..], asset_index)!;
    c3_data.append("}\n");

    File file = io::file::open(dst.path_string, "w")!;

    file.write(c3_data.str_view())!;
    file.flush()!;
    file.close()!;

    asset_index++;
    already_embedded.push(path);

    return false;
}

fn void! main()
{
    already_embedded.temp_init();

    src_path = path::temp_new("assets")!;
    dst_path = path::temp_new("assets/embeds")!;

    io::printfn("Walking assets")!;
    src_path.walk(&walk_asset, null)!;
}