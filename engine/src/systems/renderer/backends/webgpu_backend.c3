module kenzine::renderer::webgpu;

import webgpu;
import webgpu::wgpu;

import kenzine::common;
import kenzine::log;
import kenzine::platform;
import kenzine::memory;
import kenzine::math;
import kenzine::utils;

import std::time;

// TEMP
import kenzine::resource;
import kenzine::resources;
import std::io;
import std::math::vector;
// TEMP end

const usz VERTEX_BUFFER_VERTEX_COUNT = 1024 * 1024;
const usz INDEX_BUFFER_INDEX_COUNT = 1024 * 1024;

macro usz vertex_buffer_size($Type)
{
    return $Type.sizeof * VERTEX_BUFFER_VERTEX_COUNT;
}

macro usz index_buffer_size($Type)
{
    return $Type.sizeof * INDEX_BUFFER_INDEX_COUNT;
}

fault WebGPUError
{
    INSTANCE_CREATION_FAILED,
    COULD_NOT_GET_LIMITS,
    COULD_NOT_GET_NEXT_TEXTURE_VIEW,
}

struct FrameState
{
    webgpu::CommandBuffer command_buffer;
    webgpu::TextureView target_view;
    webgpu::CommandEncoder command_encoder;
    webgpu::RenderPassEncoder renderpass;
}

struct MappedBuffer
{
    webgpu::Buffer buffer;
    bool ready;
}

struct VertexBuffer
{
    webgpu::Buffer buffer;
    usz vertex_count;
}

struct IndexBuffer
{
    webgpu::Buffer buffer;
    usz index_count;
}

struct Uniforms
{
    float time;
}

struct UniformBuffer
{
    webgpu::Buffer buffer;
    Uniforms uniforms;
}

struct WebGPUBackend(RendererBackend)
{
    webgpu::Instance instance;
    webgpu::Adapter adapter;
    webgpu::AdapterInfo info;
    webgpu::Device device;
    webgpu::Queue queue;

    webgpu::Surface surface;
    webgpu::SurfaceConfiguration surface_config;

    VertexBuffer vertex_buffer;
    IndexBuffer index_buffer;

    UniformBuffer uniform_buffer;

    webgpu::RenderPipeline world_pipeline;
    webgpu::PipelineLayout world_pipeline_layout;
    webgpu::BindGroupLayout world_bindgroup_layout;
    webgpu::BindGroup world_bindgroup;

    webgpu::Color clear_color;

    FrameState frame_state;
}

fn webgpu::VertexFormat math::VertexFormat.to_webgpu_format(self)
{
    switch (self)
    {
        case math::VertexFormat.FLOAT32_2:
            return webgpu::VertexFormat.FLOAT_32X2;
        case math::VertexFormat.FLOAT32_3:
            return webgpu::VertexFormat.FLOAT_32X3;
        case math::VertexFormat.FLOAT32_4:
            return webgpu::VertexFormat.FLOAT_32X4;
    }
}

fn webgpu::InstanceDescriptor create_instance_descriptor()
{
    webgpu::InstanceDescriptor descriptor;
    descriptor.next = null;
    return descriptor;
}

fn void! WebGPUBackend.resize(WebGPUBackend* self, usz width, usz height) @dynamic
{
    self.surface.unconfigure();

    self.surface_config.width = (CUInt) width;
    self.surface_config.height = (CUInt) height;

    self.surface.configure(&self.surface_config);
}

fn void! WebGPUBackend.initialize(WebGPUBackend* self, RendererParams* params) @dynamic
{
    webgpu::InstanceDescriptor descriptor = create_instance_descriptor();
    // Create WebGPU instance
    self.instance = webgpu::createInstance(&descriptor);
    if (self.instance == (Instance) null)
    {
        return WebGPUError.INSTANCE_CREATION_FAILED?;
    }

    // Request adapter
    // adapter.c3i line 59
    RequestAdapterOptions options;
    options.next = null;
    options.powerPreference = webgpu::PowerPreference.HIGH_PERFORMANCE;

    webgpu::Adapter! adapter = self.instance.requestAdapter(&options);
    if (catch err = adapter)
    {
        return err?;
    }

    self.clear_color = params.clear_color.to_webgpu_color();

    self.adapter = adapter;
    self.adapter.getInfo(&self.info);

    self.print_adapter_info()!;

    // Request device
    DeviceDescriptor deviceDescriptor;
    deviceDescriptor.next = null;
    deviceDescriptor.label = params.device_label;
    deviceDescriptor.requiredFeatureCount = 0;
    deviceDescriptor.requiredFeatures = null;
    deviceDescriptor.requiredLimits = null;
    deviceDescriptor.defaultQueue.next = null;
    deviceDescriptor.defaultQueue.label = "Kenzine Default Queue";
    deviceDescriptor.deviceLostCallback = &on_device_lost;
    deviceDescriptor.uncapturedErrorCallbackInfo.next = null;
    deviceDescriptor.uncapturedErrorCallbackInfo.callback = &on_device_error;

    webgpu::RequiredLimits required_limits = self.get_requirements(&params.requirements)!;
    deviceDescriptor.requiredLimits = &required_limits;

    webgpu::Device! device = self.adapter.requestDevice(&deviceDescriptor);
    if (catch err = device)
    {
        return err?;
    }

    self.device = device;

    self.print_device_info()!;

    self.queue = self.device.getQueue();
    self.queue.onSubmittedWorkDone(&on_queue_submitted_work_done, null);

    SurfaceDescriptor surfaceDescriptor;
    surfaceDescriptor.label = "Kenzine Surface";

    // https://github.com/eliemichel/glfw3webgpu/blob/main/glfw3webgpu.c
$if(env::WIN32):
    SurfaceDescriptorFromWindowsHWND surfaceDescriptorPlatform;
    surfaceDescriptorPlatform.chain.next = null;
    surfaceDescriptorPlatform.chain.sType = SType.SURFACE_DESCRIPTOR_FROM_WINDOWS_HWND;
    surfaceDescriptorPlatform.hinstance = (webgpu::HInstance) platform::platform.h_instance;
    surfaceDescriptorPlatform.hwnd = (webgpu::WindowsHWND) platform::platform.h_window;

    surfaceDescriptor.next = &surfaceDescriptorPlatform.chain;
$endif

    self.surface = self.instance.createSurface(&surfaceDescriptor);

    SurfaceConfiguration surfaceConfig;
    surfaceConfig.next = null;
    surfaceConfig.width = (CUInt) params.swapchain_width;
    surfaceConfig.height = (CUInt) params.swapchain_height;

    TextureUsage usage;
    usage.renderAttachment = true;

    // https://github.com/webgpu-native/webgpu-headers/issues/290
    SurfaceCapabilities capabilities;
    capabilities.next = null;
    self.surface.getCapabilities(self.adapter, &capabilities);

    TextureFormat format = capabilities.formats[0];
    capabilities.freeMembers();

    surfaceConfig.format = format;
    surfaceConfig.viewFormatCount = 0;
    surfaceConfig.viewFormats = null;
    surfaceConfig.usage = usage;
    surfaceConfig.device = self.device;
    surfaceConfig.presentMode = PresentMode.FIFO;
    surfaceConfig.alphaMode = CompositeAlphaMode.AUTO;

    self.surface.configure(&surfaceConfig);
    self.surface_config = surfaceConfig;

    RenderPipelineDescriptor pipelineDescriptor;
    pipelineDescriptor.next = null;

    // TEMP
    Resource shader;
    resource::load(ResourceType.SHADER, "builtin2d", &shader)!;
    String code = resources::shader::get_code(&shader)!;
    String vertex_entry = resources::shader::get_entry(&shader, SupportedShaderStage.VERTEX);
    String fragment_entry = resources::shader::get_entry(&shader, SupportedShaderStage.FRAGMENT);
    // TEMP end

    // Vertex stage
    VertexBufferLayout vertexBufferLayout;

    String vertex_type = resources::shader::get_vertex_type(&shader);
    VertexAttribute[] attributes = get_vertex_attributes(vertex_type);
    vertexBufferLayout.attributeCount = attributes.len;
    vertexBufferLayout.attributes = attributes.ptr;

    if (vertex_type == "vertex2d")
    {
        vertexBufferLayout.arrayStride = Vertex2d.sizeof;
    }
    else if (vertex_type == "vertex3d")
    {
        vertexBufferLayout.arrayStride = Vertex3d.sizeof;
    }

    vertexBufferLayout.stepMode = VertexStepMode.VERTEX;

    VertexBufferLayout[] vertexBufferLayouts = 
    {
        vertexBufferLayout,
    };

    pipelineDescriptor.vertex.bufferCount = 1; 
    pipelineDescriptor.vertex.buffers = vertexBufferLayouts.ptr; // attribute buffers

    ShaderModuleDescriptor shaderModuleDescriptor;
    shaderModuleDescriptor.hintCount = 0;
    shaderModuleDescriptor.hints = null;

    // TODO: use the config for determine what to use here
    ShaderModuleWGSLDescriptor shaderModuleWGSLDescriptor;
    shaderModuleWGSLDescriptor.chain.next = null;
    shaderModuleWGSLDescriptor.chain.sType = SType.SHADER_MODULE_WGSL_DESCRIPTOR;
    shaderModuleWGSLDescriptor.code = (ZString) code;
    shaderModuleDescriptor.next = &shaderModuleWGSLDescriptor.chain;

    ShaderModule shaderModule = self.device.createShaderModule(&shaderModuleDescriptor);

    pipelineDescriptor.vertex.shaderModule = shaderModule;
    pipelineDescriptor.vertex.entryPoint = (ZString) vertex_entry;
    pipelineDescriptor.vertex.constantCount = 0;
    pipelineDescriptor.vertex.constants = null;

    // Primitive stage
    pipelineDescriptor.primitive.topology = PrimitiveTopology.TRIANGLE_LIST;
    pipelineDescriptor.primitive.stripIndexFormat = IndexFormat.UNDEFINED;
    pipelineDescriptor.primitive.frontFace = FrontFace.COUNTER_CLOCKWISE;
    pipelineDescriptor.primitive.cullMode = CullMode.NONE;

    // Fragment stage
    FragmentState fragmentState;
    fragmentState.next = null;
    fragmentState.shaderModule = shaderModule;
    fragmentState.entryPoint = (ZString) fragment_entry;
    fragmentState.constantCount = 0;
    fragmentState.constants = null;
    pipelineDescriptor.fragment = &fragmentState;

    // Depth stencil stage
    pipelineDescriptor.depthStencil = null;

    // Blending stage
    BlendState blendState;
    blendState.color.sourceFactor = BlendFactor.SRC_ALPHA;
    blendState.color.destinationFactor = BlendFactor.ONE_MINUS_SRC_ALPHA;
    blendState.color.operation = BlendOperation.ADD;

    blendState.alpha.sourceFactor = BlendFactor.ZERO;
    blendState.alpha.destinationFactor = BlendFactor.ONE;
    blendState.alpha.operation = BlendOperation.ADD;

    ColorWriteMask mask;
    mask.red = true;
    mask.green = true;
    mask.blue = true;
    mask.alpha = true;

    ColorTargetState colorTargetState;
    colorTargetState.next = null;
    colorTargetState.format = format;
    colorTargetState.blend = &blendState;
    colorTargetState.writeMask = mask;

    fragmentState.targetCount = 1;
    fragmentState.targets = &colorTargetState;

    // Multisample stage
    pipelineDescriptor.multisample.count = 1;
    pipelineDescriptor.multisample.mask = ~0u;
    pipelineDescriptor.multisample.alphaToCoverageEnabled = CBool.FALSE;

    // Uniform binding
    webgpu::BindGroupLayoutEntry bindingLayout;
    bindingLayout.set_defaults();
    bindingLayout.binding = 0;
    bindingLayout.visibility.vertex = true;
    bindingLayout.buffer.type = BufferBindingType.UNIFORM;
    bindingLayout.buffer.minBindingSize = Uniforms.sizeof < 16 ? 16 : Uniforms.sizeof;

    webgpu::BindGroupLayoutDescriptor bindGroupLayoutDescriptor;
    bindGroupLayoutDescriptor.next = null;
    bindGroupLayoutDescriptor.label = "Kenzine Bind Group Layout";
    bindGroupLayoutDescriptor.entryCount = 1;
    bindGroupLayoutDescriptor.entries = &bindingLayout;
    self.world_bindgroup_layout = self.device.createBindGroupLayout(&bindGroupLayoutDescriptor);

    // Pipeline layout
    webgpu::PipelineLayoutDescriptor pipelineLayoutDescriptor;
    pipelineLayoutDescriptor.next = null;
    pipelineLayoutDescriptor.label = "Kenzine Pipeline Layout";
    pipelineLayoutDescriptor.bindGroupLayoutCount = 1;
    pipelineLayoutDescriptor.bindGroupLayouts = &self.world_bindgroup_layout;
    self.world_pipeline_layout = self.device.createPipelineLayout(&pipelineLayoutDescriptor);

    pipelineDescriptor.layout = self.world_pipeline_layout;

    self.world_pipeline = self.device.createRenderPipeline(&pipelineDescriptor);

    shaderModule.release();

    // TEMP
    memory::kfree_many(code.ptr - 3, char, (code.len + 3), MemoryTag.SHADER)!;
    resource::unload(&shader)!;

    self.create_buffers()!;
    self.create_bindgroups()!;
}

fn void webgpu::BindGroupLayoutEntry.set_defaults(self)
{
    self.buffer.next = null;
    self.buffer.type = BufferBindingType.UNDEFINED;
    self.buffer.hasDynamicOffset = CBool.FALSE;

    self.sampler.next = null;
    self.sampler.type = SamplerBindingType.UNDEFINED;

    self.storageTexture.next = null;
    self.storageTexture.access = StorageTextureAccess.UNDEFINED;
    self.storageTexture.format = TextureFormat.UNDEFINED;
    self.storageTexture.viewDimension = TextureViewDimension.UNDEFINED;

    self.texture.next = null;
    self.texture.multisampled = CBool.FALSE;
    self.texture.sampleType = TextureSampleType.UNDEFINED;
    self.texture.viewDimension = TextureViewDimension.UNDEFINED;
}

fn VertexAttribute[] get_vertex_attributes(String vertex_type)
{
    switch (vertex_type)
    {
        case "vertex2d":
            VertexAttribute[math::vertex2d_attribute_count()] attributes;
            for (usz i = 0; i < math::vertex2d_attribute_count(); i++)
            {
                VertexAttribute attribute;
                attribute.shaderLocation = (CULong) i;
                attribute.offset = math::vertex2d_attribute_offset(i);
                attribute.format = math::vertex2d_attribute_format(i).to_webgpu_format();
                attributes[i] = attribute;
            }

            return attributes[0..];    
        case "vertex3d": 
            VertexAttribute[math::vertex3d_attribute_count()] attributes;
            for (usz i = 0; i < math::vertex3d_attribute_count(); i++)
            {
                VertexAttribute attribute;
                attribute.shaderLocation = (CULong) i;
                attribute.offset = math::vertex3d_attribute_offset(i);
                attribute.format = math::vertex3d_attribute_format(i).to_webgpu_format();
                attributes[i] = attribute;
            }

            return attributes[0..];          
    } 

    VertexAttribute[1] attributes;
    return attributes[0..];
}

fn void set_vertex_stride(String vertex_type, VertexBufferLayout* vertexBufferLayout)
{
    if (vertex_type == "vertex2d")
    {
        vertexBufferLayout.arrayStride = Vertex2d.sizeof;
    }
    else if (vertex_type == "vertex3d")
    {
        vertexBufferLayout.arrayStride = Vertex3d.sizeof;
    }
}

fn TextureView WebGPUBackend.get_next_surface_texture_view(WebGPUBackend* self)
{
    SurfaceTexture texture;
    self.surface.getCurrentTexture(&texture);

    if (texture.status != CurrentTextureStatus.SUCCESS)
    {
        return null;
    }

    TextureViewDescriptor viewDescriptor;
    viewDescriptor.next = null;
    viewDescriptor.label = "Kenzine Surface Texture View";
    viewDescriptor.format = texture.texture.getFormat();
    viewDescriptor.dimension = TextureViewDimension.SINGLE_2D;
    viewDescriptor.baseMipLevel = 0;
    viewDescriptor.mipLevelCount = 1;
    viewDescriptor.baseArrayLayer = 0;
    viewDescriptor.arrayLayerCount = 1;
    viewDescriptor.aspect = TextureAspect.ALL;

    TextureView view = texture.texture.createView(&viewDescriptor);
    return view;
}

fn void! WebGPUBackend.create_bindgroups(WebGPUBackend* self)
{
    webgpu::BindGroupEntry binding;
    binding.next = null;
    binding.binding = 0;
    binding.buffer = self.uniform_buffer.buffer;
    binding.offset = 0;
    binding.size = Uniforms.sizeof < 16 ? 16 : Uniforms.sizeof;

    webgpu::BindGroupDescriptor bindGroupDescriptor;
    bindGroupDescriptor.next = null;
    bindGroupDescriptor.label = "Kenzine Bind Group";
    bindGroupDescriptor.layout = self.world_bindgroup_layout;
    bindGroupDescriptor.entryCount = 1;
    bindGroupDescriptor.entries = &binding;
    self.world_bindgroup = self.device.createBindGroup(&bindGroupDescriptor);
}

fn void! WebGPUBackend.release_bindgroups(WebGPUBackend* self)
{
    self.world_bindgroup.release();
}

fn void! WebGPUBackend.create_buffers(WebGPUBackend* self)
{
    BufferUsage usage;
    usage.copyDestination = true;
    usage.vertex = true;
    BufferDescriptor bufferDescriptor;
    bufferDescriptor.next = null;
    bufferDescriptor.label = "Kenzine Vertex Buffer";
    bufferDescriptor.usage = usage;
    bufferDescriptor.size = (CULongLong) vertex_buffer_size(Vertex2d); //(CULongLong) (vertices.len * Vertex2d.sizeof);
    bufferDescriptor.mappedAtCreation = CBool.FALSE;
    self.vertex_buffer.buffer = self.device.createBuffer(&bufferDescriptor);

    memory::submit_gpu_memory_allocation((usz) bufferDescriptor.size, GPUMemoryTag.VERTEX_BUFFER);

    usage.vertex = false;
    usage.index = true;
    bufferDescriptor.label = "Kenzine Index Buffer";
    bufferDescriptor.usage = usage;
    bufferDescriptor.size = (CULongLong) index_buffer_size(Index);
    bufferDescriptor.size = (bufferDescriptor.size + 3) & ~3;
    self.index_buffer.buffer = self.device.createBuffer(&bufferDescriptor);

    memory::submit_gpu_memory_allocation((usz) bufferDescriptor.size, GPUMemoryTag.INDEX_BUFFER);

    usage.index = false;
    usage.uniform = true;
    bufferDescriptor.label = "Kenzine Uniform Buffer";
    bufferDescriptor.usage = usage;
    bufferDescriptor.size = (CULongLong) (Uniforms.sizeof < 16 ? 16 : Uniforms.sizeof);
    self.uniform_buffer.buffer = self.device.createBuffer(&bufferDescriptor);

    memory::submit_gpu_memory_allocation((usz) bufferDescriptor.size, GPUMemoryTag.UNIFORM_BUFFER);

    self.uniform_buffer.uniforms.time = 1.0;
    self.queue.writeBuffer(self.uniform_buffer.buffer, 0, &self.uniform_buffer.uniforms, Uniforms.sizeof);
}

fn void on_buffer2_mapped(BufferMapAsyncStatus status, void* buffer)
{
    MappedBuffer* buffer2 = (MappedBuffer*) buffer;

    buffer2.ready = true;
    log::log(LogLevel.INFO, "mapped with status %s", status)!!;

    if (status != BufferMapAsyncStatus.SUCCESS)
    {
        return;
    }

    char[] data = ((char*) buffer2.buffer.getMappedRange(0, 16))[0..16];
    for (int i = 0; i < 16; i++)
    {
        log::log(LogLevel.INFO, "buffer2[%d] = %d", i, data[i])!!;
    }

    buffer2.buffer.unmap();
}

fn void! WebGPUBackend.release_buffers(WebGPUBackend* self)
{
    //self.buffer1.release();
    //self.buffer2.buffer.release();

    CULongLong size = self.vertex_buffer.buffer.getSize();
    self.vertex_buffer.buffer.release();
    memory::submit_gpu_memory_deallocation((usz) size, GPUMemoryTag.VERTEX_BUFFER);

    size = self.index_buffer.buffer.getSize();
    self.index_buffer.buffer.release();
    memory::submit_gpu_memory_deallocation((usz) size, GPUMemoryTag.INDEX_BUFFER);

    size = self.uniform_buffer.buffer.getSize();
    self.uniform_buffer.buffer.release();
    memory::submit_gpu_memory_deallocation((usz) size, GPUMemoryTag.UNIFORM_BUFFER);
}

fn void! WebGPUBackend.begin_renderpass(WebGPUBackend* self, RenderPassType type) @dynamic
{
    RenderPassDescriptor renderPassDescriptor;
    renderPassDescriptor.next = null;

    RenderPassColorAttachment colorAttachment;
    colorAttachment.view = self.frame_state.target_view;
    colorAttachment.resolveTarget = null;
    colorAttachment.loadOperation = LoadOperation.CLEAR;
    colorAttachment.storeOperation = StoreOperation.STORE;
    colorAttachment.clearValue = self.clear_color;
    colorAttachment.depthSlice = 0xffffffffUL;

    renderPassDescriptor.colorAttachmentCount = 1;
    renderPassDescriptor.colorAttachments = &colorAttachment;
    renderPassDescriptor.depthStencilAttachment = null;
    renderPassDescriptor.timestampWrites = null;

    RenderPassEncoder renderpass = self.frame_state.command_encoder.beginRenderPass(&renderPassDescriptor);
    self.frame_state.renderpass = renderpass;

    self.frame_state.renderpass.setPipeline(self.world_pipeline);
}

fn void! WebGPUBackend.end_renderpass(WebGPUBackend* self,RenderPassType type) @dynamic
{
    self.frame_state.renderpass.end();
    self.frame_state.renderpass.release();
}

fn void! WebGPUBackend.apply_global_uniforms(WebGPUBackend* self, double delta_time) @dynamic
{
    self.uniform_buffer.uniforms.time += (float) delta_time;
    self.queue.writeBuffer(self.uniform_buffer.buffer, 0, &self.uniform_buffer.uniforms, Uniforms.sizeof);
}

fn void! WebGPUBackend.begin_frame(WebGPUBackend* self, double delta_time) @dynamic
{
    TextureView target_view = self.get_next_surface_texture_view();
    if ((void*) target_view == null)
    {
        return WebGPUError.COULD_NOT_GET_NEXT_TEXTURE_VIEW?;
    }

    self.frame_state.target_view = target_view;

    CommandEncoderDescriptor encoderDescriptor;
    encoderDescriptor.next = null;
    encoderDescriptor.label = "Kenzine Command Encoder";

    CommandEncoder command_encoder = self.device.createCommandEncoder(&encoderDescriptor);
    self.frame_state.command_encoder = command_encoder;
}

fn GeometryRenderData! WebGPUBackend.upload_geometry(WebGPUBackend* self, GeometryData* geometry) @dynamic
{
    CULongLong previous_vertex_offset = 0;
    if (geometry.vertex_type == "vertex2d")
    {
        Vertex2d[] vertices = geometry.vertices_2d.array_view();
        previous_vertex_offset = self.vertex_buffer.vertex_count * Vertex2d.sizeof;

        self.queue.writeBuffer(self.vertex_buffer.buffer, previous_vertex_offset, vertices.ptr, vertices.len * Vertex2d.sizeof);
        self.vertex_buffer.vertex_count += vertices.len;
    }
    else if (geometry.vertex_type == "vertex3d")
    {
        Vertex3d[] vertices = geometry.vertices_3d.array_view();
        previous_vertex_offset = self.vertex_buffer.vertex_count * Vertex3d.sizeof;

        self.queue.writeBuffer(self.vertex_buffer.buffer, previous_vertex_offset, vertices.ptr, vertices.len * Vertex3d.sizeof);
        self.vertex_buffer.vertex_count += vertices.len;
    }

    Index[] indices = geometry.indices.array_view();
    CULongLong previous_index_offset = self.index_buffer.index_count * Index.sizeof;

    self.queue.writeBuffer(self.index_buffer.buffer, previous_index_offset, indices.ptr, indices.len * Index.sizeof);
    self.index_buffer.index_count += indices.len;

    return
    {
        .geometry = geometry,
        .index_offset = previous_index_offset,
        .vertex_offset = previous_vertex_offset,
    };
}

fn void! WebGPUBackend.draw_geometry(WebGPUBackend* self, GeometryRenderData* geometry) @dynamic
{
    CULongLong vertex_offset = geometry.vertex_offset;
    CULongLong vertex_size = 0;
    if (geometry.geometry.vertex_type == "vertex2d")
    {
        vertex_size = geometry.geometry.vertices_2d.len() * Vertex2d.sizeof;
    }
    else if (geometry.geometry.vertex_type == "vertex3d")
    {
        vertex_size = geometry.geometry.vertices_3d.len() * Vertex3d.sizeof;
    }

    CULongLong index_offset = geometry.index_offset;
    CULongLong index_size = geometry.geometry.indices.len() * Index.sizeof;

    self.frame_state.renderpass.setVertexBuffer(0, self.vertex_buffer.buffer, vertex_offset, vertex_size);
    self.frame_state.renderpass.setIndexBuffer(self.index_buffer.buffer, IndexFormat.UINT32, index_offset, index_size);

    self.frame_state.renderpass.setBindGroup(0, self.world_bindgroup, 0, null);

    //self.frame_state.renderpass.draw((CUInt) self.vertex_buffer.vertex_count, 1, 0, 0);
    self.frame_state.renderpass.drawIndexed((CUInt) self.index_buffer.index_count, 1, 0, 0, 0);
}

fn void! WebGPUBackend.end_frame(WebGPUBackend* self, double delta_time) @dynamic
{
    CommandBufferDescriptor bufferDescriptor;
    bufferDescriptor.next = null;
    bufferDescriptor.label = "Kenzine Command Buffer";

    self.frame_state.command_buffer = self.frame_state.command_encoder.finish(&bufferDescriptor);
    self.frame_state.command_encoder.release();

    self.queue.submit(1, &self.frame_state.command_buffer);
    self.frame_state.command_buffer.release();

    self.frame_state.target_view.release();

    self.surface.present();

    self.device.poll(CBool.FALSE, null);
}

fn void! WebGPUBackend.shutdown(WebGPUBackend* self) @dynamic
{
    log::log(LogLevel.INFO, "Releasing bindgroups...")!;
    self.release_bindgroups()!;

    log::log(LogLevel.INFO, "Releasing pipeline layout...")!;
    self.world_pipeline_layout.release();

    log::log(LogLevel.INFO, "Releasing bindgroup layout...")!;
    self.world_bindgroup_layout.release();

    log::log(LogLevel.INFO, "Releasing buffers...")!;
    self.release_buffers()!;

    log::log(LogLevel.INFO, "Releasing world pipeline...")!;
    self.world_pipeline.release();

    //self.device.poll(CBool.FALSE, null);

    log::log(LogLevel.INFO, "Releasing queue...")!;
    self.queue.release();
    self.queue = null;

    log::log(LogLevel.INFO, "Releasing device...")!;
    self.device.release();
    self.device = null;

    webgpu::freeInfoMembers(&self.info);

    log::log(LogLevel.INFO, "Unconfiguring surface...")!;
    self.surface.unconfigure();

    log::log(LogLevel.INFO, "Releasing surface...")!;
    self.surface.release();
    self.surface = null;

    log::log(LogLevel.INFO, "Releasing adapter...")!;
    self.adapter.release();
    self.adapter = null;

    log::log(LogLevel.INFO, "Releasing instance...")!;
    self.instance.release();
    self.instance = null;
}

fn void! WebGPUBackend.print_adapter_info(WebGPUBackend* self)
{
    DString report = dstring::temp_new();

    report.append("\n\nWebGPU Adapter Report\n");

    webgpu::SupportedLimits limits;
    limits.next = null;
    if (self.adapter.getLimits(&limits) != CBool.TRUE)
    {
        return WebGPUError.COULD_NOT_GET_LIMITS?;
    }

    report.append("Limits:\n");
    report.appendf("- maxTextureDimension1D: %d\n", limits.limits.maxTextureDimension1D);
    report.appendf("- maxTextureDimension2D: %d\n", limits.limits.maxTextureDimension2D);
    report.appendf("- maxTextureDimension3D: %d\n", limits.limits.maxTextureDimension3D);
    report.appendf("- maxTextureArrayLayers: %d\n", limits.limits.maxTextureArrayLayers);
    report.appendf("- maxVertexAttributes: %d\n", limits.limits.maxVertexAttributes);
    report.appendf("- maxInterStageShaderComponents: %d\n", limits.limits.maxInterStageShaderComponents);
    report.appendf("- maxBufferSize: %d\n", limits.limits.maxBufferSize);

    usz featureCount = self.adapter.enumerateFeatures(null);
    report.append("Features:\n");
    report.appendf("Feature count: %d\n", featureCount);

    const usz MAX_FEATURE_COUNT = 64;
    FeatureName[MAX_FEATURE_COUNT] features;
    self.adapter.enumerateFeatures(features[:featureCount]);

    for (usz i = 0; i < featureCount; i++)
    {
        if ((long) features[i] >= FeatureName.elements)
        {
            if ((long) features[i] <= WGPUNativeFeature.FORCE_32.value)
            {
                for (usz j = 0; j < WGPUNativeFeature.elements; j++)
                {
                    WGPUNativeFeature feature = (WGPUNativeFeature) j;
                    if (feature.value == (long) features[i])
                    {
                        report.appendf("- wgpu-native extension %s\n", feature);
                    }
                }
            }
            else
            {
                report.appendf("- Unknown feature 0x%x\n", features[i]);
            }
        }
        else
        {
            report.appendf("- %s\n", features[i]);
        }
    }

    report.append("\nProperties:\n");
    report.appendf("- Device: %s (%d)\n", self.info.device, self.info.deviceID);
    report.appendf("- Vendor: %s (%d)\n", self.info.vendor, self.info.vendorID);
    report.appendf("- Architecture: %s\n", self.info.architecture);
    report.appendf("- Description: %s\n", self.info.description);
    report.appendf("- Backend type: %s\n", self.info.backendType);
    report.appendf("- Adapter type: %s\n", self.info.adapterType);

    log::log(LogLevel.INFO, report.str_view())!;
}

fn void! WebGPUBackend.print_device_info(WebGPUBackend* self)
{
    DString report = dstring::temp_new();

    report.append("\n\nWebGPU Device Report\n");

    webgpu::SupportedLimits limits;
    limits.next = null;
    if (self.device.getLimits(&limits) != CBool.TRUE)
    {
        return WebGPUError.COULD_NOT_GET_LIMITS?;
    }

    report.append("Limits:\n");
    report.appendf("- maxTextureDimension1D: %d\n", limits.limits.maxTextureDimension1D);
    report.appendf("- maxTextureDimension2D: %d\n", limits.limits.maxTextureDimension2D);
    report.appendf("- maxTextureDimension3D: %d\n", limits.limits.maxTextureDimension3D);
    report.appendf("- maxTextureArrayLayers: %d\n", limits.limits.maxTextureArrayLayers);
    report.appendf("- maxVertexAttributes: %d\n", limits.limits.maxVertexAttributes);
    report.appendf("- maxInterStageShaderComponents: %d\n", limits.limits.maxInterStageShaderComponents);
    report.appendf("- maxBufferSize: %d\n", limits.limits.maxBufferSize);

    usz featureCount = self.device.enumerateFeatures(null);
    report.append("Features:\n");
    report.appendf("Feature count: %d\n", featureCount);

    const usz MAX_FEATURE_COUNT = 64;
    FeatureName[MAX_FEATURE_COUNT] features;
    self.device.enumerateFeatures(features[:featureCount]);

    for (usz i = 0; i < featureCount; i++)
    {
        if ((long) features[i] >= FeatureName.elements)
        {
            if ((long) features[i] <= WGPUNativeFeature.FORCE_32.value)
            {
                for (usz j = 0; j < WGPUNativeFeature.elements; j++)
                {
                    WGPUNativeFeature feature = (WGPUNativeFeature) j;
                    if (feature.value == (long) features[i])
                    {
                        report.appendf("- wgpu-native extension %s\n", feature);
                    }
                }
            }
            else
            {
                report.appendf("- Unknown feature 0x%x\n", features[i]);
            }
        }
        else
        {
            report.appendf("- %s\n", features[i]);
        }
    }

    log::log(LogLevel.INFO, report.str_view())!;
}

fn void! WebGPUBackend.check_requirements(WebGPUBackend* self, RendererRequirements* requirements) @dynamic
{

}

fn webgpu::RequiredLimits! WebGPUBackend.get_requirements(WebGPUBackend* self, RendererRequirements* requirements) @dynamic
{
    webgpu::SupportedLimits supported_limits;
    supported_limits.next = null;
    if (self.adapter.getLimits(&supported_limits) != CBool.TRUE)
    {
        return WebGPUError.COULD_NOT_GET_LIMITS?;
    }

    webgpu::RequiredLimits limits;
    limits.limits.maxTextureDimension1D = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxTextureDimension2D = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxTextureDimension3D = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxTextureArrayLayers = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxBindGroups = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxBindGroupsPlusVertexBuffers = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxBindingsPerBindGroup = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxDynamicUniformBuffersPerPipelineLayout = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxDynamicStorageBuffersPerPipelineLayout = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxSampledTexturesPerShaderStage = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxSamplersPerShaderStage = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxStorageBuffersPerShaderStage = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxStorageTexturesPerShaderStage = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxUniformBuffersPerShaderStage = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxUniformBufferBindingSize = webgpu::LIMIT_U64_UNDEFINED;
    limits.limits.maxStorageBufferBindingSize = webgpu::LIMIT_U64_UNDEFINED;
    limits.limits.maxVertexBuffers = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxBufferSize = webgpu::LIMIT_U64_UNDEFINED;
    limits.limits.maxVertexAttributes = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxVertexBufferArrayStride = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxInterStageShaderComponents = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxInterStageShaderVariables = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxColorAttachments = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxColorAttachmentBytesPerSample = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeWorkgroupStorageSize = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeInvocationsPerWorkgroup = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeWorkgroupSizeX = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeWorkgroupSizeY = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeWorkgroupSizeZ = webgpu::LIMIT_U32_UNDEFINED;
    limits.limits.maxComputeWorkgroupsPerDimension = webgpu::LIMIT_U32_UNDEFINED;

    limits.limits.minUniformBufferOffsetAlignment = supported_limits.limits.minUniformBufferOffsetAlignment;
    limits.limits.minStorageBufferOffsetAlignment = supported_limits.limits.minStorageBufferOffsetAlignment;

    limits.limits.maxVertexAttributes = requirements.max_vertex_attributes;
    limits.limits.maxVertexBuffers = requirements.max_vertex_buffers;

    if (requirements.max_buffer_size == 0)
    {
        requirements.max_buffer_size = vertex_buffer_size(Vertex3d);
    }

    limits.limits.maxBufferSize = requirements.max_buffer_size;
    limits.limits.maxVertexBufferArrayStride = requirements.max_vertex_buffer_stride;
    limits.limits.maxInterStageShaderComponents = requirements.max_interstage_shader_components;

    return limits;
}

fn void on_device_lost(DeviceLostReason reason, ZString message, UserData data)
{
    log::log(LogLevel.ERROR, "Device lost for reason %s: %s", reason, message)!!;
}

fn void on_device_error(ErrorType type, ZString message, UserData data)
{
    log::log(LogLevel.ERROR, "Device error of type %s: %s", type, message)!!;
}

fn void on_queue_submitted_work_done(QueueWorkDoneStatus status, UserData data)
{
    log::log(LogLevel.INFO, "Queue work done with status %s", status)!!;
}