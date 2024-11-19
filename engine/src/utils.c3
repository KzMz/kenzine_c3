module kenzine::utils;

enum ByteSize : int(usz byte_size, String unit)
{
    GIGA = { 1024 * 1024 * 1024, "GiB" },
    MEGA = { 1024 * 1024, "MiB" },
    KILO = { 1024, "KiB" },
    BYTE =  { 1, "B" },
}

fn String size_string(usz size)
{
    DString result = dstring::new();
    defer result.free();

    for (int i = 0; i < ByteSize.elements; ++i)
    {
        if (size >= ByteSize.values[i].byte_size)
        {
            size /= ByteSize.values[i].byte_size;
            result.appendf("%d %s", size, ByteSize.values[i].unit);
            return result.copy_str();
        }
    }

    return "0 B";
}

macro ptr_to_slice($PtrType, $SliceType, ptr)
{
    return (($SliceType*) ptr)[0..$PtrType.sizeof];
}

macro slice_to_ptr($PtrType, slice)
{
    return ($PtrType*) slice.ptr;
}