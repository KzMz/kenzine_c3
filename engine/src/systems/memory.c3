module kenzine::memory;

import kenzine::core;
import kenzine::faults;
import kenzine::app;
import kenzine::log;
import kenzine::utils;
import std::collections::map;

enum MemoryTag : int(String description)
{
    NONE = "UNTAGGED",
    GAME = "GAME\t",
    RENDERER = "RENDERER",
    APP = "APP\t",
    TEXTURE = "TEXTURE\t",
    TEXT = "TEXT\t",
    
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

    HashMap(<void*, usz>) allocations;
}

struct MemoryParams
{
    Allocator default_allocator;
}

def CoreSystem = kenzine::core::System(<MemoryState, MemoryParams>);
struct MemorySystem(CoreSystem)
{
    MemoryState* state;
}

MemoryState* memory_state = null;

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
    usz size = memory_state.allocations.get(ptr)!!;
    free(ptr, size, self.current_tag)!!;
}

KenzineAllocator kenzine_allocator;

fn void! MemorySystem.initialize(MemorySystem* self, MemoryState* state, MemoryParams* params) @dynamic
{
    kenzine_allocator.current_tag = MemoryTag.CUSTOM;
    memory_state = state;

    self.state = state;
    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    if (params == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    self.state.allocations.new_init();

    self.state.total_size = 0;
    self.state.total_allocations = 0;

    for (int i = 0; i < MemoryTag.len; i++)
    {
        self.state.tagged_memory[i].total_size = 0;
        self.state.tagged_memory[i].num_allocations = 0;
        self.state.tagged_memory[i].allocator = params.default_allocator;
    }
}

fn void! MemorySystem.shutdown(MemorySystem* self) @dynamic
{
    // TODO: destroy all arena and allocators if necessary

    self.state.allocations.clear();
    self.state.allocations.free();
}

fn usz MemorySystem.get_state_size(MemorySystem* self) @dynamic
{
    return MemoryState.sizeof;
}

fn void*! allocate(usz size, MemoryTag tag)
{
    if (memory_state == null)
    {
        return allocator::heap().acquire(size, AllocInitType.ZERO)!;
    }

    void* ptr = memory_state.tagged_memory[tag].allocator.acquire(size, AllocInitType.ZERO)!;

    memory_state.total_size += size;
    memory_state.total_allocations++;
    memory_state.tagged_memory[tag].total_size += size;
    memory_state.tagged_memory[tag].num_allocations++;

    memory_state.allocations.set(ptr, size);
    return ptr;
}

fn void*! resize(usz size, void* ptr, MemoryTag tag)
{
    if (memory_state == null)
    {
        return allocator::heap().resize(ptr, size)!;
    }

    usz old_size = memory_state.allocations.get(ptr)!;
    void* new_ptr = memory_state.tagged_memory[tag].allocator.resize(ptr, size)!;

    usz size_diff = size - old_size;
    memory_state.total_size += size_diff;
    memory_state.tagged_memory[tag].total_size += size_diff;

    return new_ptr;
}

fn void! free(void* ptr, usz size, MemoryTag tag)
{
    if (memory_state == null)
    {
        return allocator::heap().release(ptr, false);
    }

    memory_state.tagged_memory[tag].allocator.release(ptr, false);

    memory_state.total_size -= size;
    memory_state.total_allocations--;
    memory_state.tagged_memory[tag].total_size -= size;
    memory_state.tagged_memory[tag].num_allocations--;

    memory_state.allocations.remove(ptr);
}

macro kallocate($Type, tag)
{
    return ($Type*) allocate($Type.sizeof, tag);
}

// We need this to allocate slices
macro kallocate_many($Type, count, tag)
{
    if (memory_state == null)
    {
        return allocator::new_array(allocator::heap(), $Type, count);
    }

    $Type[] slice = allocator::new_array(memory_state.tagged_memory[tag].allocator, $Type, count);
    usz size = count * $Type.sizeof;

    memory_state.total_size += size;
    memory_state.total_allocations++;
    memory_state.tagged_memory[tag].total_size += size;
    memory_state.tagged_memory[tag].num_allocations++;

    memory_state.allocations.set(&slice[0], size);

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
    if (memory_state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    DString report = dstring::new();
    defer report.free();

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