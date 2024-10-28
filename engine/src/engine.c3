module engine;

fn int sum(int a, int b) @export("sum") @extern("sum") @wasm
{
    return a + b;
}