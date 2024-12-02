module kenzine::common;

import webgpu;

def Color4f = float[<4>];

fn webgpu::Color Color4f.to_webgpu_color(Color4f color)
{
    return webgpu::Color
    {
        .red = color.r,
        .green = color.g,
        .blue = color.b,
        .alpha = color.a,
    };
}