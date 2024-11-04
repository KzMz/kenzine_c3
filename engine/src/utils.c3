module kenzine::utils;

fn String size_string(usz size)
{
    const usz GB = 1024 * 1024 * 1024;
    const usz MB = 1024 * 1024;
    const usz KB = 1024;

    DString result = dstring::new();
    defer result.free();

    if (size >= GB)
    {
        size /= GB;
        result.appendf("%d GiB", size);
    }
    else if (size >= MB)
    {
        size /= MB;
        result.appendf("%d MiB", size);
    }
    else if (size >= KB)
    {
        size /= KB;
        result.appendf("%d KiB", size);
    }
    else
    {
        result.appendf("%d B", size);
    }
    return result.copy_str();
}