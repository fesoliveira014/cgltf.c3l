# cgltf.c3l

C3 bindings for [cgltf](https://github.com/jkuhlmann/cgltf), a single-header glTF 2.0 parser
written in C. Module `gltf`, package `cgltf`, C3 0.8.3.

The binding is C3-first. `src/gltf.c3i` mirrors every public cgltf type layout-exact, with
adjacent pointer-and-count pairs declared as C3 slices, and declares every C function with
`@cname`. `src/gltf.c3` adds faults for every non-success `cgltf_result` and wrappers that take
and return slices and strings and allocate through a caller allocator. `src/layout.c3` pins the
size and alignment of every struct against the real header; `scripts/probe-layout.sh --check`
regenerates and compares the pins.

## Using it

Add the repository as a git submodule (or copy it) into the directory your project searches for
libraries, then name `cgltf` as a dependency:

```json
{
  "dependency-search-paths": [ "lib" ],
  "dependencies": [ "cgltf" ]
}
```

The implementation translation unit `csrc/cgltf.c` is compiled through the package's `c-sources`
on `linux-x64` and `windows-x64`; there is no native archive to fetch. The Windows target sets
`"wincrt": "static"`.

```c3
import gltf;

fn void? show(String path) {
    gltf::Data* data = gltf::parse_file(path)!;
    defer gltf::free(data);
    gltf::load_buffers(data, path)!;
    gltf::validate(data)!;
    foreach (&node : data.nodes) {
        io::printfn("%s has %d children", node.name.str_view(), node.children.len);
    }
    gltf::Accessor* positions = data.meshes[0].primitives[0].find_accessor(gltf::AttributeType.POSITION);
    float[] floats = positions.unpack_floats(mem)!;
    defer free(floats.ptr);
}
```

`parse` and `parse_file` return the raw `Data*`; `free` releases it and every buffer
`load_buffers` loaded. Wrapper faults: `DATA_TOO_SHORT`, `UNKNOWN_FORMAT`, `INVALID_JSON`,
`INVALID_GLTF`, `INVALID_OPTIONS`, `FILE_NOT_FOUND`, `IO_ERROR`, `OUT_OF_MEMORY`, `LEGACY_GLTF`.
A raw extern whose name a wrapper also uses carries the `_raw` suffix (`parse_raw`,
`validate_raw`, `accessor_unpack_floats_raw`); the others keep the plain name (`free`,
`node_index`, `num_components`).

## Development

```sh
scripts/probe-layout.sh --check                  # layout pins against the host C compiler
c3c compile-only --no-obj src/*.c3i src/*.c3     # syntax check; remove obj/ afterwards
cd test && c3c test                              # smoke test on fixtures/triangle.glb
```

`scripts/probe-layout.sh --update` rewrites `scripts/abi-sizes.txt` and `src/layout.c3` after a
cgltf upgrade. CI runs the probe and the smoke test on `ubuntu-24.04` and `windows-2022`.
