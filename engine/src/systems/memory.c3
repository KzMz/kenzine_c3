module kenzine::memory;

import kenzine::core;
import kenzine::faults;
import kenzine::app;
import kenzine::log;
import kenzine::utils;
import std::collections::map;
import std::io;

const usz MAX_SINGLE_ALLOCATION_SIZE = 1000000;

enum MemoryTag : int(String description)
{
    NONE = "UNTAGGED",
    GAME = "GAME\t",
    RENDERER = "RENDERER",
    APP = "APP\t",
    TEXTURE = "TEXTURE\t",
    TEXT = "TEXT\t",
    SHADER = "SHADER\t",
    WASM = "WASM\t",
    BINARY = "BINARY\t",
    
    CUSTOM = "CUSTOM\t",
}

struct TaggedMemory
{
    usz total_size;
    usz num_allocations;
    Allocator allocator;
}

struct MemoryState
{
    usz total_size;
    usz total_allocations;

    TaggedMemory[MemoryTag.len] tagged_memory;
}

struct MemoryParams
{
    Allocator default_allocator;
}

struct MemorySystem(kenzine::core::System(<MemoryParams>))
{
    bool dummy;
}

MemoryState memory_state;
HashMap(<long, usz>) allocations;

struct KenzineAllocator(Allocator)
{
    MemoryTag current_tag;
}

fn void*! KenzineAllocator.acquire(KenzineAllocator* self, usz size, AllocInitType init, usz alignment) @dynamic
{
    return allocate(size, self.current_tag)!;
}

fn void*! KenzineAllocator.resize(KenzineAllocator* self, void* ptr, usz size, usz alignment) @dynamic
{
    return resize(size, ptr, self.current_tag)!;
}

fn void KenzineAllocator.release(KenzineAllocator* self, void* ptr, bool aligned) @dynamic
{
    // see if it makes sense to do this inside free() directly
    usz size = allocations.get((long) ptr)!!;
    free(ptr, size, self.current_tag)!!;
}

KenzineAllocator kenzine_allocator;
Allocator default_allocator;

fn void! MemorySystem.initialize(MemorySystem* self, MemoryParams* params) @dynamic
{
    kenzine_allocator.current_tag = MemoryTag.CUSTOM;

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    allocations.init(allocator::heap());

    memory_state.total_size = 0;
    memory_state.total_allocations = 0;

    for (int i = 0; i < MemoryTag.len; i++)
    {
        memory_state.tagged_memory[i].total_size = 0;
        memory_state.tagged_memory[i].num_allocations = 0;
        memory_state.tagged_memory[i].allocator = params.default_allocator;
    }

    default_allocator = params.default_allocator;
}

fn void! MemorySystem.shutdown(MemorySystem* self) @dynamic
{
    // TODO: destroy all arena and allocators if necessary

    allocations.clear();
    allocations.free();
}

fn usz MemorySystem.get_state_size(MemorySystem* self) @dynamic
{
    return MemoryState.sizeof;
}

fn void*! allocate(usz size, MemoryTag tag)
{
    if (size == 0 || size == usz.max || size > MAX_SINGLE_ALLOCATION_SIZE)
    {
        return null;
    }

    void* ptr = get_allocator(tag).acquire(size, AllocInitType.ZERO)!;

    memory_state.total_size += size;
    memory_state.total_allocations++;
    memory_state.tagged_memory[tag].total_size += size;
    memory_state.tagged_memory[tag].num_allocations++;

    allocations.set((long) ptr, size);
    return ptr;
}

fn void*! resize(usz size, void* ptr, MemoryTag tag)
{
    usz old_size = allocations.get((long) ptr)!;
    void* new_ptr = get_allocator(tag).resize(ptr, size)!;

    usz size_diff = size - old_size;
    memory_state.total_size += size_diff;
    memory_state.tagged_memory[tag].total_size += size_diff;

    allocations.remove((long) ptr);
    allocations.set((long) new_ptr, size);

    return new_ptr;
}

fn void! free(void* ptr, usz size, MemoryTag tag)
{
    if (ptr == null)
    {
        return;
    }

    if (size == 0 || size == usz.max || size > MAX_SINGLE_ALLOCATION_SIZE)
    {
        return;
    }

    if (!allocations.has_key((long) ptr))
    {
        return;
    }

    allocations.remove((long) ptr);

    get_allocator(tag).release(ptr, false);

    memory_state.total_size -= size;
    memory_state.total_allocations--;
    memory_state.tagged_memory[tag].total_size -= size;
    memory_state.tagged_memory[tag].num_allocations--;
}

fn Allocator get_allocator(MemoryTag tag)
{
    if (memory_state.tagged_memory[tag].allocator)
    {
        return memory_state.tagged_memory[tag].allocator;
    }

    if (default_allocator)
    {
        return default_allocator;
    }

    return allocator::heap();
}

macro kallocate($Type, tag)
{
    return ($Type*) allocate($Type.sizeof, tag);
}

// We need this to allocate slices
macro kallocate_many($Type, count, tag)
{
    $Type[] slice = allocator::new_array(get_allocator(tag), $Type, count);
    usz size = count * $Type.sizeof;

    memory_state.total_size += size;
    memory_state.total_allocations++;
    memory_state.tagged_memory[tag].total_size += size;
    memory_state.tagged_memory[tag].num_allocations++;

    allocations.set((long) &slice[0], size);

    return slice;
}

macro kfree(ptr, $Type, tag)
{
    free(ptr, $Type.sizeof, tag)!;
}

macro kfree_many(ptr, $Type, count, tag)
{
    free(ptr, $Type.sizeof * count, tag)!;
}

macro Allocator kallocator() => &kenzine_allocator;

fn void! log_memory_report()
{
    DString report = dstring::temp_new();
    usz size = memory_state.total_size;

    report.append("\n\nMemory Report\n");
    report.appendf("Total size: %s\t Total allocations: %d\n", utils::size_string(size), memory_state.total_allocations);

    for (int i = 0; i < MemoryTag.len; i++)
    {
        size = memory_state.tagged_memory[i].total_size;

        String description = MemoryTag.values[i].description;
        report.appendf("%s\tTotal size:\t%s\tTotal allocations:\t%d\n",
            description,
            utils::size_string(size),
            memory_state.tagged_memory[i].num_allocations);
    }

    log::log(LogLevel.INFO, report.str_view())!;
}