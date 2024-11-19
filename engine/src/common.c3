module kenzine::common;

import webgpu;

struct Color
{
    float r;
    float g;
    float b;
    float a;
}

fn webgpu::Color Color.to_webgpu_color(Color color)
{
    return webgpu::Color
    {
        .red = color.r,
        .green = color.g,
        .blue = color.b,
        .alpha = color.a,
    };
}