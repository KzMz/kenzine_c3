# kenzine c3
3d engine with c3 for recreational purposes

## How to build
Just run "build.bat" for native build and build-web.bat for web build

## TODO
- [x] Window Resize handling
- [x] Embedder improvements by specifying if an asset (and its dependencies) should be embedded or not
- [ ] Geometry asset definition and loader
- [ ] Material asset definition and loader
- [ ] WebGPU requirements in JS
- [ ] Check for "inline" for structs to see if we can parent something and reduce code duplication
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