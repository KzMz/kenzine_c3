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
    DString result = dstring::temp_new();

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

macro ptr_to_slice_string(ptr, size)
{
    return ((char*) ptr)[0..size];
}

macro ptr_to_slice($PtrType, $SliceType, ptr)
{
    return (($SliceType*) ptr)[0..$PtrType.sizeof];
}

macro slice_to_ptr($PtrType, slice)
{
    return ($PtrType*) slice.ptr;
}

// TODO: find if there is a better way to do this
macro offset_of_index($Type, index)
{
    $switch ($Type.membersof.len)
        $case 1: 
            return offset_of_index_($Type, 0);
        
        $case 2: 
            switch (index)
            {
                case 0: return offset_of_index_($Type, 0);
                case 1: return offset_of_index_($Type, 1);
            }

        $case 3: 
            switch (index)
            {
                case 0: return offset_of_index_($Type, 0);
                case 1: return offset_of_index_($Type, 1);
                case 2: return offset_of_index_($Type, 2);
            }
    $endswitch;

    return 0;
}

macro offset_of_index_($Type, $index) @private
{
    return $Type.membersof[$index].offsetof;
}