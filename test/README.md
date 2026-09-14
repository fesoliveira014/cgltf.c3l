# Smoke test

`c3c test` from this directory compiles the binding through the repository root, which the
search path `..` resolves as `cgltf.c3l`, and runs `src/smoke.c3` against `fixtures/triangle.glb`.

The fixture is one node, one mesh, one triangle primitive with `POSITION` and `uint16` indices,
written by:

```python
import json, struct
positions = struct.pack("<9f", 0, 0, 0, 1, 0, 0, 0, 1, 0)
indices = struct.pack("<3H", 0, 1, 2) + b"\0\0"
payload = positions + indices
document = {
    "asset": {"version": "2.0"},
    "scene": 0, "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "triangle", "mesh": 0}],
    "meshes": [{"primitives": [{"attributes": {"POSITION": 0}, "indices": 1}]}],
    "buffers": [{"byteLength": len(payload)}],
    "bufferViews": [
        {"buffer": 0, "byteOffset": 0, "byteLength": 36},
        {"buffer": 0, "byteOffset": 36, "byteLength": 6}],
    "accessors": [
        {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]},
        {"bufferView": 1, "componentType": 5123, "count": 3, "type": "SCALAR"}],
}
text = json.dumps(document).encode()
text += b" " * (-len(text) % 4)
header = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(payload))
glb = header + struct.pack("<I4s", len(text), b"JSON") + text + struct.pack("<I4s", len(payload), b"BIN\0") + payload
open("fixtures/triangle.glb", "wb").write(glb)
```
