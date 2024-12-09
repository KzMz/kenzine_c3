function make_env(...envs) {
    return new Proxy(envs, {
        get(target, prop, receiver) {
            for (const env of envs) {
                if (env.hasOwnProperty(prop))
                    return env[prop];
            }
            return (...args) => {
                console.error(`No such property: ${prop}`)
            }
        }
    });
}

// Thanks to rexim https://github.com/c3lang/c3c/pull/1440
function read_string_from_memory(wasm, buffer, len) {
    const decoder = new TextDecoder();
    return decoder.decode(new Uint8ClampedArray(wasm.instance.exports.memory.buffer, buffer, len));
}

class Uniforms {
    time = 0.0;
}

class Kenzine {

    constructor(canvas_id) {
        this.wasm = undefined;
        this.canvas = undefined;
        this.previousTimestamp = 0;

        this.adapter = undefined;
        this.context = undefined;
        this.device = undefined;
        this.encoder = undefined;
        this.pass = undefined;
        this.pipeline = undefined;
        this.worldPipelineLayout = undefined;
        this.worldBindGroup = undefined;
        this.worldBindGroupLayout = undefined;

        this.vertexBuffer = {
            buffer: undefined,
            count: 0
        };
        this.indexBuffer = {
            buffer: undefined,
            count: 0
        };
        this.uniformBuffer = {
            buffer: undefined,
            uniforms: new Uniforms()
        }
        this.clearColor = { r: 0.0, g: 0.0, b: 0.0, a: 1.0 };

        this.canvas = document.getElementById(canvas_id);
    }

    get exports() {
        if (!this.wasm) return undefined;
        return this.wasm.instance.exports;
    }

    get memory() {
        if (!this.wasm) return undefined;
        return this.wasm.instance.exports.memory;
    }

    async run(wasm_file) {
        this.wasm = await this.getKenzineWasm(wasm_file);

        this.exports._initialize();
        this.exports.main();
    }

    load_resource(type, name)
    {
        const name_ptr = this.exports.allocate(name.length);
        const name_array = new Uint8ClampedArray(this.memory.buffer, name_ptr, name.length);

        for (let i = 0; i < name.length; i++) {
            name_array[i] = name.charCodeAt(i);
        }
        name_array[name.length] = 0;
        
        return this.exports.load_resource(type, name_ptr, name_array.length - 1);
    }
    
    getImports() {
        return {
            wasm_write: (buffer, len) => {
                console.log(read_string_from_memory(this.wasm, buffer, len));
            },
            /*wasm_load_resource: async (buffer, len) => {
                const path = read_string_from_memory(this.wasm, buffer, len);

                const response = await fetch(path);
                const array = new Uint8ClampedArray(await response.arrayBuffer());

                const data_ptr = this.wasm.instance.exports.allocate(array.length, 7);
                const data = new Uint8ClampedArray(this.wasm.instance.exports.memory.buffer, data_ptr, array.length);
                data.set(array);

                this.wasm.instance.exports.on_resource_loaded(data_ptr, array.length);
            },*/
            app_set_title: (buffer, len) => {
                this.title = read_string_from_memory(this.wasm, buffer, len);
            },
            canvas_resize: (width, height) => {
                this.resize(width, height);
            },
            canvas_move: (x, y) => {
                this.move(x, y);
            },
            app_setup_loop: () => {
                this.setup_loop();
            },
            get_absolute_time: () => {
                return window.performance.now() / 1000.0;
            },
            // Renderer
            renderer_initialize: async () => {
                await this.initialize_renderer();
            },
            renderer_shutdown: async () => {
                await this.shutdown_renderer();
            },
            renderer_begin_frame: async (delta_time) => {
                await this.begin_frame(delta_time);
            },
            renderer_draw_frame: async (delta_time) => {
                await this.draw_frame(delta_time);
            },
            renderer_end_frame: async (delta_time) => {
                await this.end_frame(delta_time);
            },
            renderer_begin_renderpass: async (type) => {
                await this.begin_renderpass(type);
            },
            renderer_end_renderpass: async (type) => {
                await this.end_renderpass(type);
            },
            renderer_set_clear_color: (color_ptr) => {
                const color = new Float32Array(this.memory.buffer, color_ptr, 4);
                this.clearColor = { r: color[0], g: color[1], b: color[2], a: color[3] };
            },
        };
    }

    async getKenzineWasm(wasm_file) {
        return await WebAssembly.instantiateStreaming(fetch(wasm_file), {
            "env": make_env(this.getImports())
        });
    }

    frame(timestamp) {
        const delta_time = (timestamp - this.previousTimestamp) / 1000.0;
        this.previousTimestamp = timestamp;

        this.exports.app_loop(delta_time);
        window.requestAnimationFrame(this.frame.bind(this));
    }

    setup_loop() {

    }

    resize(width, height) {
        this.canvas.width = width;
        this.canvas.height = height;
    }

    move(x, y) {
        const currentLeft = this.canvas.style.left;
        const currentTop = this.canvas.style.top;

        this.canvas.style.left = `calc(${x}px + ${currentLeft})`;
        this.canvas.style.top = `calc(${y}px + ${currentTop})`;
    }

    get_attribute_format_string(attribute_index) {
        const format = this.exports.vertex2d_get_attribute_format(attribute_index);
        
        switch (format) {
            case 0: return "float32x2";
            case 1: return "float32x3";
            case 2: return "float32x4";
        }
        
        return "float32x2";
    }

    async initialize_renderer() {
        if (!navigator.gpu) {
            throw new Error("WebGPU not supported on this browser.");
        }

        this.adapter = await navigator.gpu.requestAdapter();
        if (!this.adapter) {
            throw new Error("No appropriate GPUAdapter found.");
        }

        this.device = await this.adapter.requestDevice();
        if (!this.device) {
            throw new Error("No appropriate GPUDevice found.");
        }

        const context = this.canvas.getContext("webgpu");
        const canvasFormat = navigator.gpu.getPreferredCanvasFormat();
        context.configure({
            device: this.device,
            format: canvasFormat,
        });

        this.context = context;

        // TEMP
        const resource = this.load_resource(4, "builtin");
        const code_size = this.exports.shader_get_code_size(resource);
        const code_ptr = this.exports.shader_get_code(resource);
        const code = read_string_from_memory(this.wasm, code_ptr, code_size);
        
        const shaderModule = this.device.createShaderModule({
            "code": code
        });

        // Vertex
        const vertexBufferLayout = {
            arrayStride: this.exports.vertex2d_get_size(),
            attributes: []
        };

        const vertexAttributeCount = this.exports.vertex2d_get_attribute_count();
        for (let i = 0; i < vertexAttributeCount; i++) {
            const attribute_offset = this.exports.vertex2d_get_attribute_offset(i);
            const attribute_format = this.get_attribute_format_string(i);

            vertexBufferLayout.attributes.push({
                shaderLocation: i,
                format: attribute_format,
                offset: attribute_offset
            });
        }

        let entry_size = this.exports.shader_get_entry_size(resource, 0);
        let entry_ptr = this.exports.shader_get_entry(resource, 0);
        let entry = read_string_from_memory(this.wasm, entry_ptr, entry_size);
        const vertex = {
            module: shaderModule,
            entryPoint: entry,
            buffers: [vertexBufferLayout]
        };

        // Fragment
        entry_size = this.exports.shader_get_entry_size(resource, 1);
        entry_ptr = this.exports.shader_get_entry(resource, 1);
        entry = read_string_from_memory(this.wasm, entry_ptr, entry_size);
        const fragment = {
            module: shaderModule,
            entryPoint: entry,
            targets: [
                {
                    format: canvasFormat
                }
            ]
        };

        this.worldBindGroupLayout = this.device.createBindGroupLayout({
            label: "Kenzine Bind Group Layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX,
                    buffer: {
                        type: "uniform",
                        minBindingSize: 4 * 4
                    }
                }
            ]
        });

        this.worldPipelineLayout = this.device.createPipelineLayout({
            label: "Kenzine Pipeline Layout",
            bindGroupLayouts: [this.worldBindGroupLayout]
        });

        this.pipeline = this.device.createRenderPipeline({
            layout: this.worldPipelineLayout,
            vertex: vertex,
            fragment: fragment,
            primitive: {
                topology: "triangle-list",
            }
        });

        this.create_buffers();
        this.create_bindgroups();

        this.exports.log_memory_report();

        window.requestAnimationFrame((timestamp) => {
            this.previousTimestamp = timestamp;
            window.requestAnimationFrame(this.frame.bind(this));
        })
    }

    create_buffers() {
        // TODO: retrieve from wasm after we have geometry assets
        const vertices = new Float32Array([
            -0.5, -0.5, 0.0, 0.0,     1.0, 0.0, 0.0, 1.0,
             0.5, -0.5, 0.0, 0.0,     0.0, 1.0, 0.0, 1.0,
             0.5,  0.5, 0.0, 0.0,     0.0, 0.0, 1.0, 1.0,
            -0.5,  0.5, 0.0, 0.0,     1.0, 1.0, 0.0, 1.0,
        ]);

        this.vertexBuffer.count = vertices.length / 6;
        this.vertexBuffer.buffer = this.device.createBuffer({
            label: "Kenzine Vertex Buffer",
            size: vertices.byteLength,
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST
        });

        this.device.queue.writeBuffer(this.vertexBuffer.buffer, 0, vertices);
        this.exports.submit_gpu_memory_allocation(this.vertexBuffer.buffer.size, 1);

        const indices = new Uint32Array([
            0, 1, 2,
            0, 2, 3
        ]);

        this.indexBuffer.buffer = this.device.createBuffer({
            label: "Kenzine Index Buffer",
            size: indices.byteLength,
            usage: GPUBufferUsage.INDEX | GPUBufferUsage.COPY_DST
        });
        this.indexBuffer.count = indices.length;

        this.device.queue.writeBuffer(this.indexBuffer.buffer, 0, indices);
        this.exports.submit_gpu_memory_allocation(this.indexBuffer.buffer.size, 1);

        this.uniformBuffer.buffer = this.device.createBuffer({
            label: "Kenzine Uniform Buffer",
            size: 4 * 4,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST
        });

        this.uniformBuffer.uniforms.time = 1.0;
        this.device.queue.writeBuffer(this.uniformBuffer.buffer, 0, new Float32Array([this.uniformBuffer.uniforms.time, 0.0, 0.0, 0.0]));
        this.exports.submit_gpu_memory_allocation(this.uniformBuffer.buffer.size, 1);
    }

    create_bindgroups() {
        this.worldBindGroup = this.device.createBindGroup({
            layout: this.worldBindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: {
                        buffer: this.uniformBuffer.buffer,
                        offset: 0,
                        size: 4 * 4
                    }
                }
            ]
        });
    }

    async begin_frame(delta_time) {
        this.uniformBuffer.uniforms.time += delta_time;
        this.device.queue.writeBuffer(this.uniformBuffer.buffer, 0, new Float32Array([this.uniformBuffer.uniforms.time, 0.0, 0.0, 0.0]));

        this.encoder = this.device.createCommandEncoder();
    }

    async draw_frame(delta_time) {
        this.pass.setPipeline(this.pipeline);

        this.pass.setVertexBuffer(0, this.vertexBuffer.buffer);
        this.pass.setIndexBuffer(this.indexBuffer.buffer, "uint32", 0);
        this.pass.setBindGroup(0, this.worldBindGroup);

        this.pass.drawIndexed(this.indexBuffer.count, 1, 0, 0, 0);
    }

    async end_frame(delta_time) {
        this.device.queue.submit([this.encoder.finish()]);
    }

    async begin_renderpass(type) {
        const colorAttachment = {
            view: this.context.getCurrentTexture().createView(),
            loadOp: 'clear',
            storeOp: 'store',
            clearValue: this.clearColor,
        };
        const renderPassDescriptor = {
            colorAttachments: [colorAttachment],
        };

        this.pass = this.encoder.beginRenderPass(renderPassDescriptor);
    }

    async end_renderpass(type) {
        this.pass.end();
    }

    async shutdown_renderer() {
        this.uniformBuffer.buffer = undefined;
        this.indexBuffer.buffer = undefined;
        this.vertexBuffer.buffer = undefined;
        this.pipeline = undefined;
        this.pass = undefined;
        this.encoder = undefined;
        this.context = undefined;

        this.device = undefined;
        this.adapter = undefined;
    }

    set title(title) {
        document.title = title;
    }
}

const kenzine = new Kenzine("game");
await kenzine.run("playground.wasm");