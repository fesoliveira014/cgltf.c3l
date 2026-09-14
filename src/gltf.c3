module gltf;

import libc;

faultdef
    DATA_TOO_SHORT,
    UNKNOWN_FORMAT,
    INVALID_JSON,
    INVALID_GLTF,
    INVALID_OPTIONS,
    FILE_NOT_FOUND,
    IO_ERROR,
    OUT_OF_MEMORY,
    LEGACY_GLTF;

const usz INDEX_BYTES @local = 4;

<*
 Parse glTF or GLB bytes; the returned data borrows nothing from the slice.
 @param bytes : "Borrowed for the call."
 @return? DATA_TOO_SHORT, UNKNOWN_FORMAT, INVALID_JSON, INVALID_GLTF, INVALID_OPTIONS, OUT_OF_MEMORY, LEGACY_GLTF
*>
fn Data*? parse(char[] bytes, Options options = {}) {
    Data* data;
    check(parse_raw(&options, bytes.ptr, bytes.len, &data))!;
    return data;
}

<*
 Parse a glTF or GLB file.
 @return? DATA_TOO_SHORT, UNKNOWN_FORMAT, INVALID_JSON, INVALID_GLTF, INVALID_OPTIONS, FILE_NOT_FOUND, IO_ERROR
 @return? OUT_OF_MEMORY, LEGACY_GLTF
*>
fn Data*? parse_file(String path, Options options = {}) {
    Data* data;
    @pool() {
        check(parse_file_raw(&options, path.zstr_tcopy(), &data))!;
    };
    return data;
}

<*
 Load every buffer: GLB payload, data URIs, and files relative to the path's directory.
 @param [&inout] data : "Buffers become owned by the data until free."
 @return? DATA_TOO_SHORT, UNKNOWN_FORMAT, INVALID_GLTF, INVALID_OPTIONS, FILE_NOT_FOUND, IO_ERROR, OUT_OF_MEMORY
*>
fn void? load_buffers(Data* data, String gltf_path, Options options = {}) {
    @pool() {
        check(load_buffers_raw(&options, data, gltf_path.zstr_tcopy()))!;
    };
    return;
}

<*
 Check the parsed document against the specification's structural rules.
 @return? INVALID_GLTF
*>
fn void? validate(Data* data) {
    return check(validate_raw(data));
}

<*
 Decode a base64 payload into the allocator; the C buffer is released before returning.
 @param base64 : "Text after the data URI comma; whole quartets with = padding."
 @return? INVALID_GLTF, OUT_OF_MEMORY
*>
fn char[]? decode_base64(Allocator allocator, String base64, Options options = {}) {
    if (base64.len % 4 != 0) return INVALID_GLTF~;
    usz padding = 0;
    if (base64.len >= 1 && base64[^1] == '=') padding++;
    if (base64.len >= 2 && base64[^2] == '=') padding++;
    usz size = base64.len / 4 * 3 - padding;

    void* decoded;
    @pool() {
        Result result = load_buffer_base64_raw(&options, size, base64.zstr_tcopy(), &decoded);
        if (result == IO_ERROR) return INVALID_GLTF~;
        check(result)!;
    };
    defer release(&options, decoded);

    char[] copy = alloc::new_array(allocator, char, (sz)size);
    mem::copy(copy.ptr, decoded, (sz)size);
    return copy;
}

<*
 Bytes of the view through its buffer or extension-supplied data.
 @return "Empty when neither source is loaded."
*>
fn char[] BufferView.bytes(&self) {
    char* start = buffer_view_data_raw(self);
    if (!start) return {};
    return start[:self.size];
}

<*
 Column-major local matrix of the node.
*>
fn float[16] Node.local_matrix(&self) {
    float[16] matrix;
    node_transform_local_raw(self, &matrix);
    return matrix;
}

<*
 Column-major world matrix through the parent chain.
*>
fn float[16] Node.world_matrix(&self) {
    float[16] matrix;
    node_transform_world_raw(self, &matrix);
    return matrix;
}

<*
 Accessor of the attribute, null when the primitive lacks it.
*>
fn Accessor* Primitive.find_accessor(&self, AttributeType type, int index = 0) {
    return find_accessor_raw(self, type, index);
}

<*
 Read one element as floats, normalizing integer components.
 @param out : "One element's components."
 @return "False when the element cannot be read."
*>
fn bool Accessor.read_float(&self, usz index, float[] out) {
    return accessor_read_float_raw(self, index, out.ptr, out.len) != 0;
}

<*
 Read one element as unsigned integers.
 @return "False when the element cannot be read."
*>
fn bool Accessor.read_uint(&self, usz index, uint[] out) {
    return accessor_read_uint_raw(self, index, out.ptr, out.len) != 0;
}

<*
 Every element's components as floats, allocated with the allocator.
 @return? INVALID_GLTF
*>
fn float[]? Accessor.unpack_floats(&self, Allocator allocator) {
    usz float_count = self.count * self.component_count();
    float[] floats = alloc::new_array(allocator, float, (sz)float_count);
    if (accessor_unpack_floats_raw(self, floats.ptr, float_count) != float_count) {
        alloc::free(allocator, floats.ptr);
        return INVALID_GLTF~;
    }
    return floats;
}

<*
 Every element as a 32-bit index, allocated with the allocator.
 @return? INVALID_GLTF
*>
fn uint[]? Accessor.unpack_indices(&self, Allocator allocator) {
    uint[] indices = alloc::new_array(allocator, uint, (sz)self.count);
    if (accessor_unpack_indices_raw(self, indices.ptr, INDEX_BYTES, self.count) != self.count) {
        alloc::free(allocator, indices.ptr);
        return INVALID_GLTF~;
    }
    return indices;
}

<*
 Number of floats one element holds.
*>
fn usz Accessor.component_count(&self) {
    return num_components(self.type);
}

fn void? check(Result result) @local {
    switch (result) {
        case SUCCESS: return;
        case DATA_TOO_SHORT: return DATA_TOO_SHORT~;
        case UNKNOWN_FORMAT: return UNKNOWN_FORMAT~;
        case INVALID_JSON: return INVALID_JSON~;
        case INVALID_GLTF: return INVALID_GLTF~;
        case INVALID_OPTIONS: return INVALID_OPTIONS~;
        case FILE_NOT_FOUND: return FILE_NOT_FOUND~;
        case IO_ERROR: return IO_ERROR~;
        case OUT_OF_MEMORY: return OUT_OF_MEMORY~;
        case LEGACY_GLTF: return LEGACY_GLTF~;
        case MAX_ENUM: return INVALID_GLTF~;
    }
}

fn void release(Options* options, void* block) @local {
    if (options.memory.free_func) {
        options.memory.free_func(options.memory.user_data, block);
        return;
    }
    libc::free(block);
}
