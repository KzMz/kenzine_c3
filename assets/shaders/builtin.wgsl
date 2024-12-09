struct VertexInput {
    @location(0) position: vec2f,
    @location(1) color: vec4f,
}

struct VertexOutput {
    @builtin(position) position: vec4f,
    @location(0) color: vec4f,
}

@group(0) @binding(0) var<uniform> uTime: f32;

@vertex
fn vertex_main(in: VertexInput) -> VertexOutput {
    var out: VertexOutput;

    var offset = vec2f(0.0, 0.0);
    offset += 0.3 * vec2f(cos(uTime), sin(uTime));

    out.position = vec4f(in.position + offset, 0.0, 1.0);
    out.color = in.color;
    return out;
}

@fragment
fn fragment_main(in: VertexOutput) -> @location(0) vec4f {
    let linear_color = pow(in.color, vec4f(2.2)); // Gamma-correction
    return linear_color;
}