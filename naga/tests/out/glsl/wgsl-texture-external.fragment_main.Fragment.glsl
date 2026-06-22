#version 310 es

precision highp float;
precision highp int;

struct NagaExternalTextureTransferFn {
    float a;
    float b;
    float g;
    float k;
};
struct NagaExternalTextureParams {
    mat4x4 yuv_conversion_matrix;
    mat3x3 gamut_conversion_matrix;
    NagaExternalTextureTransferFn src_tf;
    NagaExternalTextureTransferFn dst_tf;
    mat3x2 sample_transform;
    mat3x2 load_transform;
    uvec2 size;
    uint num_planes;
};
layout(binding = 0) uniform highp sampler2D tex_plane0_;
layout(binding = 1) uniform highp sampler2D tex_plane1_;
layout(binding = 2) uniform highp sampler2D tex_plane2_;
layout(std430, binding = 0) readonly buffer NagaExternalTextureParams_block_0Fragment { NagaExternalTextureParams _member; } tex_params;

layout(location = 0) out vec4 _fs2p_location0;

vec4 nagaSampleExternalTexture(highp sampler2D plane0, highp sampler2D plane1, highp sampler2D plane2, NagaExternalTextureParams params, vec2 coords) {
    vec2 plane0_size = vec2(textureSize(plane0, 0));
    coords = (params.sample_transform * vec3(coords, 1.0));
    vec2 bounds_min = (params.sample_transform * vec3(0.0, 0.0, 1.0));
    vec2 bounds_max = (params.sample_transform * vec3(1.0, 1.0, 1.0));
    vec4 bounds = vec4(min(bounds_min, bounds_max), max(bounds_min, bounds_max));
    vec2 plane0_half_texel = vec2(0.5) / plane0_size;
    vec2 plane0_coords = clamp(coords, bounds.xy + plane0_half_texel, bounds.zw - plane0_half_texel);
    if (params.num_planes == 1u) {
        return textureLod(plane0, plane0_coords, 0.0);
    } else {
        vec2 plane1_size = vec2(textureSize(plane1, 0));
        vec2 plane1_half_texel = vec2(0.5) / plane1_size;
        vec2 plane1_coords = clamp(coords, bounds.xy + plane1_half_texel, bounds.zw - plane1_half_texel);
        float y = textureLod(plane0, plane0_coords, 0.0).r;
        vec2 uv = vec2(0.0, 0.0);
        if (params.num_planes == 2u) {
            uv = textureLod(plane1, plane1_coords, 0.0).xy;
        } else {
            vec2 plane2_size = vec2(textureSize(plane2, 0));
            vec2 plane2_half_texel = vec2(0.5) / plane2_size;
            vec2 plane2_coords = clamp(coords, bounds.xy + plane2_half_texel, bounds.zw - plane2_half_texel);
            uv.x = textureLod(plane1, plane1_coords, 0.0).x;
            uv.y = textureLod(plane2, plane2_coords, 0.0).x;
        }
        vec3 srcGammaRgb = (params.yuv_conversion_matrix * vec4(y, uv, 1.0)).rgb;
        vec3 srcLinearRgb = mix(
            pow((srcGammaRgb + params.src_tf.a - 1.0) / params.src_tf.a, vec3(params.src_tf.g)),
            srcGammaRgb / params.src_tf.k,
            lessThan(srcGammaRgb, vec3(params.src_tf.k * params.src_tf.b)));
        vec3 dstLinearRgb = params.gamut_conversion_matrix * srcLinearRgb;
        vec3 dstGammaRgb = mix(
            params.dst_tf.a * pow(dstLinearRgb, vec3(1.0 / params.dst_tf.g)) - (params.dst_tf.a - 1.0),
            params.dst_tf.k * dstLinearRgb,
            lessThan(dstLinearRgb, vec3(params.dst_tf.b)));
        return vec4(dstGammaRgb, 1.0);
    }
}

vec4 nagaTextureLoadExternal(highp sampler2D plane0, highp sampler2D plane1, highp sampler2D plane2, NagaExternalTextureParams params, ivec2 coords) {
    uvec2 plane0_size = uvec2(textureSize(plane0, 0));
    uvec2 cropped_size = (params.size != uvec2(0u)) ? params.size : plane0_size;
    coords = min(coords, ivec2(cropped_size - uvec2(1u)));
    ivec2 plane0_coords = ivec2(round(params.load_transform * vec3(vec2(coords), 1.0)));
    if (params.num_planes == 1u) {
        return texelFetch(plane0, plane0_coords, 0);
    } else {
        uvec2 plane1_size = uvec2(textureSize(plane1, 0));
        ivec2 plane1_coords = ivec2(floor(vec2(plane0_coords) * vec2(plane1_size) / vec2(plane0_size)));
        float y = texelFetch(plane0, plane0_coords, 0).x;
        vec2 uv = vec2(0.0, 0.0);
        if (params.num_planes == 2u) {
            uv = texelFetch(plane1, plane1_coords, 0).xy;
        } else {
            uvec2 plane2_size = uvec2(textureSize(plane2, 0));
            ivec2 plane2_coords = ivec2(floor(vec2(plane0_coords) * vec2(plane2_size) / vec2(plane0_size)));
            uv.x = texelFetch(plane1, plane1_coords, 0).x;
            uv.y = texelFetch(plane2, plane2_coords, 0).x;
        }
        vec3 srcGammaRgb = (params.yuv_conversion_matrix * vec4(y, uv, 1.0)).rgb;
        vec3 srcLinearRgb = mix(
            pow((srcGammaRgb + params.src_tf.a - 1.0) / params.src_tf.a, vec3(params.src_tf.g)),
            srcGammaRgb / params.src_tf.k,
            lessThan(srcGammaRgb, vec3(params.src_tf.k * params.src_tf.b)));
        vec3 dstLinearRgb = params.gamut_conversion_matrix * srcLinearRgb;
        vec3 dstGammaRgb = mix(
            params.dst_tf.a * pow(dstLinearRgb, vec3(1.0 / params.dst_tf.g)) - (params.dst_tf.a - 1.0),
            params.dst_tf.k * dstLinearRgb,
            lessThan(dstLinearRgb, vec3(params.dst_tf.b)));
        return vec4(dstGammaRgb, 1.0);
    }
}

uvec2 nagaTextureDimensionsExternal(highp sampler2D plane0, highp sampler2D plane1, highp sampler2D plane2, NagaExternalTextureParams params) {
    return (params.size != uvec2(0u)) ? params.size : uvec2(textureSize(plane0, 0));
}

vec4 test(highp sampler2D t_plane0_, highp sampler2D t_plane1_, highp sampler2D t_plane2_, NagaExternalTextureParams t_params) {
    vec4 a = vec4(0.0);
    vec4 b = vec4(0.0);
    vec4 c = vec4(0.0);
    uvec2 d = uvec2(0u);
    vec4 _e4 = nagaSampleExternalTexture(t_plane0_, t_plane1_, t_plane2_, t_params, vec2(0.0));
    a = _e4;
    vec4 _e8 = nagaTextureLoadExternal(t_plane0_, t_plane1_, t_plane2_, t_params, ivec2(ivec2(0)));
    b = _e8;
    vec4 _e12 = nagaTextureLoadExternal(t_plane0_, t_plane1_, t_plane2_, t_params, ivec2(uvec2(0u)));
    c = _e12;
    d = uvec2(nagaTextureDimensionsExternal(t_plane0_, t_plane1_, t_plane2_, t_params).xy);
    vec4 _e16 = a;
    vec4 _e17 = b;
    vec4 _e19 = c;
    uvec2 _e21 = d;
    return (((_e16 + _e17) + _e19) + vec2(_e21).xyxy);
}

void main() {
    vec4 _e1 = test(tex_plane0_, tex_plane1_, tex_plane2_, tex_params._member);
    _fs2p_location0 = _e1;
    return;
}

