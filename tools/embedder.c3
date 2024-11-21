import std::io;
import std::io::file;
import std::io::path;
import std::hash::md5;

Path src_path;
Path dst_path;

usz asset_index = 0;

fn bool! walk_asset(Path path, bool is_dir, void* data)
{
    if (is_dir) return false;
    if (path.path_string.contains("embeds")) return false;

    usz size = io::file::get_size(path.path_string)!;
    char[] buffer = allocator::new_array(allocator::heap(), char, size);
    buffer = io::file::load_buffer(path.path_string, buffer)!;

    DString c3_name = dstring::temp_new(path.basename());
    c3_name.append(".c3");

    Path dst = dst_path.new_append(c3_name.str_view())!;
    io::printfn("Embedding asset: %s in %s", path.path_string, dst.path_string)!;

    DString c3_data = dstring::temp_new("module kenzine::assets;\n\n");
    c3_data.append("import kenzine::resources::cache;\n");
    c3_data.append("import std::io;\n\n");

    c3_data.appendf("String asset_data_%d = `%s`;\n\n", asset_index, (String) buffer[3..])!;

    Splitter splitter = path.path_string.splitter("assets");
    String split = splitter.next()!;
    split = splitter.next()!;

    DString escaped_string = dstring::temp_new(split);
    escaped_string.replace("\\", "\\\\");

    c3_data.appendf("fn void embed_asset_%d() @init(1024)\n", asset_index)!;
    c3_data.append("{\n");
    c3_data.appendf("\tio::printfn(\"Embedding asset: %s\\%s\");\n", "assets", escaped_string.str_view()[1..])!;
    c3_data.appendf("\tcache::add(\"%s\\%s\", asset_data_%d);\n", "assets", escaped_string.str_view()[1..], asset_index)!;
    c3_data.append("}\n");

    File file = io::file::open(dst.path_string, "w")!;

    file.write(c3_data.str_view())!;
    file.flush()!;
    file.close()!;

    asset_index++;

    return false;
}

fn void! main()
{
    src_path = path::temp_new("assets")!;
    dst_path = path::temp_new("assets/embeds")!;

    io::printfn("Walking assets")!;
    src_path.walk(&walk_asset, null)!;
}