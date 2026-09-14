module smoke;

import gltf;
import std::io::path;

const usz MATRIX_FLOATS = 16;

fn String fixture_path() @local {
    Path source = path::tnew($$FILEPATH)!!;
    return (String)source.parent()!!.tappend("../fixtures", "triangle.glb")!!;
}

fn gltf::Data* parse_fixture() @local {
    gltf::Data* data = gltf::parse($embed("../fixtures/triangle.glb"))!!;
    gltf::load_buffers(data, fixture_path())!!;
    gltf::validate(data)!!;
    return data;
}

fn void test_parse_reads_counts_through_slice_pairs() @test {
    gltf::Data* data = parse_fixture();
    defer gltf::free(data);
    assert(data.nodes.len == 1);
    assert(data.meshes.len == 1);
    assert(data.meshes[0].primitives.len == 1);
    assert(data.meshes[0].primitives[0].attributes.len == 1);
    assert(data.nodes[0].name.str_view() == "triangle");
    assert(gltf::node_index(data, &data.nodes[0]) == 0);
}

fn void test_accessors_unpack_positions_and_indices() @test {
    gltf::Data* data = parse_fixture();
    defer gltf::free(data);
    gltf::Primitive* primitive = &data.meshes[0].primitives[0];
    gltf::Accessor* positions = primitive.find_accessor(gltf::AttributeType.POSITION);
    assert(positions != null);
    assert(positions.component_count() == 3);

    float[] floats = positions.unpack_floats(mem)!!;
    defer free(floats.ptr);
    float[9] expected_floats = { 0, 0, 0, 1, 0, 0, 0, 1, 0 };
    assert(floats == expected_floats[..]);

    float[3] one;
    assert(positions.read_float(1, one[..]));
    assert(one == (float[3]){ 1, 0, 0 });

    uint[] indices = primitive.indices.unpack_indices(mem)!!;
    defer free(indices.ptr);
    uint[3] expected_indices = { 0, 1, 2 };
    assert(indices == expected_indices[..]);

    char[] bytes = positions.buffer_view.bytes();
    assert(bytes.len == 36);
}

fn void test_untransformed_node_has_identity_matrix() @test {
    gltf::Data* data = parse_fixture();
    defer gltf::free(data);
    float[MATRIX_FLOATS] local = data.nodes[0].local_matrix();
    float[MATRIX_FLOATS] world = data.nodes[0].world_matrix();
    for (usz index = 0; index < MATRIX_FLOATS; index++) {
        float expected = index % 5 == 0 ? 1 : 0;
        assert(local[index] == expected);
        assert(world[index] == expected);
    }
}

fn void test_decode_base64_round_trips() @test {
    char[] decoded = gltf::decode_base64(mem, "AAAAAAAAgD8=")!!;
    defer free(decoded.ptr);
    char[8] expected = { 0, 0, 0, 0, 0, 0, 128, 63 };
    assert(decoded == expected[..]);
}

fn void test_truncated_bytes_are_too_short() @test {
    char[] bytes = $embed("../fixtures/triangle.glb");
    if (catch excuse = gltf::parse(bytes[:8])) {
        assert(excuse == gltf::DATA_TOO_SHORT);
    } else {
        assert(false, "expected a fault");
    }
}

fn void test_missing_file_is_not_found() @test {
    if (catch excuse = gltf::parse_file("__missing__.glb")) {
        assert(excuse == gltf::FILE_NOT_FOUND);
    } else {
        assert(false, "expected a fault");
    }
}
