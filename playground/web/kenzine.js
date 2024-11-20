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

class Kenzine {

    constructor(canvas_id) {
        this.wasm = undefined;
        this.canvas = undefined;
        this.previous_timestamp = 0;

        this.adapter = undefined;
        this.context = undefined;
        this.device = undefined;
        this.encoder = undefined;
        this.pass = undefined;
        this.clearColor = { r: 0.0, g: 0.0, b: 0.0, a: 1.0 };

        this.canvas = document.getElementById(canvas_id);
    }

    async run(wasm_file) {
        this.wasm = await this.getKenzineWasm(wasm_file);

        this.wasm.instance.exports._initialize();
        this.wasm.instance.exports.main();
    }

    getImports() {
        return {
            wasm_write: (buffer, len) => {
                console.log(read_string_from_memory(this.wasm, buffer, len));
            },
            wasm_load_resource: async (buffer, len) => {
                const path = read_string_from_memory(this.wasm, buffer, len);

                const response = await fetch(path);
                const array = new Uint8ClampedArray(await response.arrayBuffer());

                const data_ptr = this.wasm.instance.exports.allocate(array.length, 7);
                const data = new Uint8ClampedArray(this.wasm.instance.exports.memory.buffer, data_ptr, array.length);
                data.set(array);

                this.wasm.instance.exports.on_resource_loaded(data_ptr, array.length);
            },
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
            renderer_set_clear_color: (r, g, b, a) => {
                this.clearColor = { r, g, b, a };
            }
        };
    }

    async getKenzineWasm(wasm_file) {
        return await WebAssembly.instantiateStreaming(fetch(wasm_file), {
            "env": make_env(this.getImports())
        });
    }

    frame(timestamp) {
        this.previous_timestamp = timestamp;
        this.wasm.instance.exports.app_loop();
        window.requestAnimationFrame(this.frame.bind(this));
    }

    setup_loop() {

    }

    resize(width, height) {
        this.canvas.width = width;
        this.canvas.height = height;
    }

    move(x, y) {
        this.canvas.style.left = `${x}px`;
        this.canvas.style.top = `${y}px`;
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

        window.requestAnimationFrame((timestamp) => {
            this.previous_timestamp = timestamp;
            window.requestAnimationFrame(this.frame.bind(this));
        })
    }

    async begin_frame(delta_time) {
        this.encoder = this.device.createCommandEncoder();
    }

    async draw_frame(delta_time) {

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
        this.device = undefined;
        this.adapter = undefined
    }

    set title(title) {
        document.title = title;
    }
}

const kenzine = new Kenzine("game");
await kenzine.run("playground.wasm");