function make_env(...envs) {
    return new Proxy(envs, {
        get(target, prop, receiver) {
            for (const env of envs)
            {
                if (env.hasOwnProperty(prop))
                    return env[prop];
            }
            return (...args) => { console.error(`No such property: ${prop}`)}
        }
    });
}

function log(level, format, ...args)
{
    console.log(wasm);
    console.log(`[${level}] ${format}`);
}

const imports = {
    log: (level, format, ...args) => log(level, format, ...args)
};

async function getKenzineWasm() {
    return await WebAssembly.instantiateStreaming(fetch('playground.wasm'), {
        "env": make_env(imports)
    });
}

let wasm;

(async () => {
    const instance = await Promise.all([
        getKenzineWasm()
    ]);

    wasm = instance[0];
    wasm.instance.exports.main();
})();