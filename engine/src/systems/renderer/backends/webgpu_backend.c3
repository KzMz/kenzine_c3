﻿module kenzine::renderer::webgpu;

import webgpu;
import webgpu::wgpu;

import kenzine::common;
import kenzine::log;
import kenzine::platform;
import kenzine::memory;

// TEMP
import kenzine::resource;
import kenzine::resources;
import std::io;
// TEMP end

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

struct WebGPUBackend(RendererBackend)
{
    webgpu::Instance instance;
    webgpu::Adapter adapter;
    webgpu::AdapterInfo info;
    webgpu::Device device;
    webgpu::Queue queue;
    webgpu::Surface surface;

    webgpu::RenderPipeline world_pipeline;

    webgpu::Color clear_color;

    FrameState frame_state;
}

fn webgpu::InstanceDescriptor create_instance_descriptor()
{
    webgpu::InstanceDescriptor descriptor;
    descriptor.next = null;
    return descriptor;
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

    RenderPipelineDescriptor pipelineDescriptor;
    pipelineDescriptor.next = null;

    // Vertex stage
    // TODO: make this configurable
    pipelineDescriptor.vertex.bufferCount = 0; // number of attribute buffers
    pipelineDescriptor.vertex.buffers = null; // attribute buffers

    ShaderModuleDescriptor shaderModuleDescriptor;
    shaderModuleDescriptor.hintCount = 0;
    shaderModuleDescriptor.hints = null;

    // TEMP
    Resource shader;
    resource::load(ResourceType.SHADER, "builtin", &shader)!;
    String code = resources::shader::get_code(&shader)!;
    String vertex_entry = resources::shader::get_entry(&shader, SupportedShaderStage.VERTEX);
    String fragment_entry = resources::shader::get_entry(&shader, SupportedShaderStage.FRAGMENT);
    // TEMP end

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

    pipelineDescriptor.layout = null;

    self.world_pipeline = self.device.createRenderPipeline(&pipelineDescriptor);

    shaderModule.release();

    memory::kfree_many(code.ptr - 3, char, (code.len + 3), MemoryTag.SHADER)!;

    // TEMP
    resource::unload(&shader)!;
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
}

fn void! WebGPUBackend.end_renderpass(WebGPUBackend* self,RenderPassType type) @dynamic
{
    self.frame_state.renderpass.end();
    self.frame_state.renderpass.release();
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

fn void! WebGPUBackend.draw_frame(WebGPUBackend* self, double delta_time) @dynamic
{
    self.frame_state.renderpass.setPipeline(self.world_pipeline);
    self.frame_state.renderpass.draw(3, 1, 0, 0);
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