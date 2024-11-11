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

let wasm;
let canvas = undefined;
let canvas_id = "game";

let previous_timestamp = 0;

const frame = (timestamp) => {
    previous_timestamp = timestamp;
    wasm.instance.exports.app_loop();
    window.requestAnimationFrame(frame);
}

const imports = {
    wasm_write: (buffer, len) => {
        console.log(read_string_from_memory(buffer, len));
    },
    wasm_app_set_title: (buffer, len) => {
        document.title = read_string_from_memory(buffer, len);
    },
    wasm_canvas_resize: (width, height) => {
        if (canvas === undefined) {
            canvas = document.getElementById(canvas_id);
        }

        canvas.width = width;
        canvas.height = height;
    },
    wasm_canvas_move: (x, y) => {
        if (canvas === undefined) {
            canvas = document.getElementById(canvas_id);
        }

        canvas.style.left = `${x}px`;
        canvas.style.top = `${y}px`;
    },
    wasm_app_setup_loop: () => {
        window.requestAnimationFrame((timestamp) => {
            previous_timestamp = timestamp;
            window.requestAnimationFrame(frame);
        })
    },
    wasm_get_absolute_time: () => {
        return window.performance.now() / 1000.0;
    }
};

// Thanks to rexim https://github.com/c3lang/c3c/pull/1440
function read_string_from_memory(buffer, len) {
    const decoder = new TextDecoder();
    return decoder.decode(new Uint8ClampedArray(wasm.instance.exports.memory.buffer, buffer, len));
}

async function getKenzineWasm() {
    return await WebAssembly.instantiateStreaming(fetch('playground.wasm'), {
        "env": make_env(imports)
    });
}

(async () => {
    const instance = await Promise.all([
        getKenzineWasm()
    ]);

    wasm = instance[0];
    wasm.instance.exports._initialize();
    wasm.instance.exports.main();
})();