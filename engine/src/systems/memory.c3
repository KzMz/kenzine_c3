module kenzine::memory;

import kenzine::core;

enum MemoryTag : int(String description)
{
    MEMORY_TAG_NONE = "None",
    MEMORY_TAG_GAME = "Game",
    MEMORY_TAG_RENDERER = "Renderer",
    MEMORY_TAG_APP = "App",
    MEMORY_TAG_TEXTURE = "Texture",
    
    MEMORY_TAG_CUSTOM = "Custom",
}

struct TaggedMemory
{
    uint total_size;
    uint num_allocations;
    Allocator allocator;
}

struct MemoryState
{
    uint total_size;
    uint total_allocations;

    TaggedMemory[MemoryTag.len] tagged_memory;
}

struct MemoryParams
{
    Allocator default_allocator;
}

struct MemorySystem(kenzine::core::System)
{
    MemoryState* state;
}

fn void! MemorySystem.initialize(MemorySystem* self, void* state, void* params) @dynamic
{
    self.state = (MemoryState*) state;
    if (self.state == null)
    {
        return SystemError.STATE_IS_NULL?;
    }

    MemoryParams* p = (MemoryParams*) params;
    if (p == null)
    {
        return SystemError.PARAMS_IS_NULL?;
    }

    self.state.total_size = 0;
    self.state.total_allocations = 0;

    for (int i = 0; i < MemoryTag.len; i++)
    {
        self.state.tagged_memory[i].total_size = 0;
        self.state.tagged_memory[i].num_allocations = 0;
        self.state.tagged_memory[i].allocator = p.default_allocator;
    }
}

fn void! MemorySystem.shutdown(MemorySystem* self) @dynamic
{
    // TODO: destroy all arena and allocators if necessary
}

fn int MemorySystem.get_state_size(MemorySystem* self) @dynamic
{
    return MemoryState.sizeof;
}