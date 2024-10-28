async function getKenzineWasm() {
    return await WebAssembly.instantiateStreaming(fetch('playground.wasm'), {
        "kenzine": {}
    });
}

(async () => {
    const [wasm] = await Promise.all([
        getKenzineWasm()
    ]);
    console.log(wasm);
    console.log(wasm.instance.exports.sum(1, 2));
})();