// The whole model in one dispatch, for a render with no spatial effect.
//
// Halation and the DIR couplers move light between pixels, so they need the frame
// in a buffer and a chain of passes. Without them there is nothing to keep, and
// this is one invocation per pixel from the file to the file.

@compute @workgroup_size(64)
fn main(@builtin(global_invocation_id) id: vec3<u32>) {
    // One workgroup row per image row: 65 535 workgroups per dispatch
    // dimension is the WebGPU limit, which a 4 MP image already exceeds
    // in one dimension.
    if (id.x >= params.grain.z) {
        return;
    }
    let index = id.y * params.grain.z + id.x;
    if (index >= arrayLength(&source)) {
        return;
    }
    // The grain field runs over the whole frame; a band still draws the pixels
    // its global coordinate names.
    let global = index + params.band.x * params.grain.z;
    let density = develop(global, model_exposure(source[index].rgb));
    output[index] = vec4<f32>(model_positive(density), 1.0);
}
