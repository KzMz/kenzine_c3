# kenzine c3
3d engine with c3 for recreational purposes

## How to build
Just run "build.bat" for native build and build-web.bat for web build

## TODO
- [x] Dynamic uniform buffers for instancing and model-related data
- [x] Aspect ratio handling
- [ ] Material asset definition and loader
- [ ] Support for Material in Geometries
- [ ] WebGPU requirements in JS
- [ ] Check for "inline" for structs to see if we can parent something and reduce code duplication
- [ ] Check if there is something that could be rewritten using 'any' as type
- [ ] Choose and integrate an immediate mode GUI library for debug (nuklear, raygui)
- [ ] stb_image integration (https://github.com/tonis2/stb.c3/)
- [ ] Support shader code directly into builtin.shader.json file
- [ ] Support different shader files for different stages
- [ ] Support different shader formats like SPIR-V
- [ ] Check whether a window library like RGFW or GLFW is beneficial to the project
- [ ] Find a way to handle user-defined vertex and indices

## References and links
- WebGPU bindings: https://github.com/TheOnlySilverClaw/webgpu.c3l
- Lot of interop wasm stuff: https://github.com/tsoding/koil
- Win32 API interop stuff: https://github.com/kcvinker/cforms