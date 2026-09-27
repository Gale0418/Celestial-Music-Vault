#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// All masks use the source artwork's coordinates. The foreground ring, limb,
// and lighting stay in place while an original seamless cloud texture rotates on the sphere.
static float cloudMask(float2 p) {
    const float2 major = float2(0.87758256, -0.47942554);
    const float2 minor = float2(0.47942554, 0.87758256);
    float limbClearance = 553.0 - length(p - float2(1393.0, 420.0));
    float sphere = smoothstep(8.0, 40.0, limbClearance);
    float2 ringLocal = p - float2(980.0, 600.0);
    float ringX = dot(ringLocal, major) / 760.0;
    float ringY = dot(ringLocal, minor);
    float ringClearance = 1000.0;
    if (abs(ringX) < 1.1) {
        float frontArc = 72.0 * sqrt(max(0.0, 1.0 - ringX * ringX));
        ringClearance = abs(ringY - frontArc);
    }
    return sphere * smoothstep(88.0, 135.0, ringClearance);
}

[[ stitchable ]] half4 saturnAtmosphere(float2 position, SwiftUI::Layer layer,
                                       float2 size, float time, texture2d<half> clouds) {
    half4 original = layer.sample(position);
    float scale = max(size.x / 1586.0, size.y / 992.0);
    if (scale <= 0.0) return original;
    float2 origin = (size - float2(1586.0, 992.0) * scale) * 0.5;
    float2 p = (position - origin) / scale;
    float mask = cloudMask(p);
    if (mask <= 0.001) return original;

    const float2 major = float2(0.87758256, -0.47942554);
    const float2 minor = float2(0.47942554, 0.87758256);
    float2 globe = p - float2(1393.0, 420.0);
    float x = dot(globe, major) / 553.0;
    float y = dot(globe, minor) / 553.0;
    float z = sqrt(max(0.0, 1.0 - x * x - y * y));
    float2 uv = float2(atan2(x, z) / (2.0 * M_PI_F) + 0.5,
                      asin(clamp(y, -1.0, 1.0)) / M_PI_F + 0.5);

    // Seven separately rotating latitude bands. All periods divide 5760,
    // matching the Swift clock wrap, so neither time nor texture has a seam.
    // Four times the original speed so cloud features visibly travel within seconds.
    const float periods[7] = {36.0, 30.0, 45.0, 24.0, 40.0, 32.0, 48.0};
    float band = clamp(uv.y * 7.0 - 0.5, 0.0, 6.0);
    int lower = min(int(floor(band)), 5);
    float feather = smoothstep(0.32, 0.68, band - lower);
    constexpr sampler cloudSampler(coord::normalized, s_address::repeat,
                                   t_address::clamp_to_edge, filter::linear);
    half3 first = clouds.sample(cloudSampler, uv + float2(time / periods[lower], 0.0)).rgb;
    half3 second = clouds.sample(cloudSampler, uv + float2(time / periods[lower + 1], 0.0)).rgb;
    half3 cloudColor = mix(first, second, half(feather));

    // Recover broad lighting from the fixed artwork. The atmosphere texture
    // rotates independently of the illumination and foreground ring.
    float2 safeMin = float2(0.5), safeMax = max(safeMin, size - 0.5);
    half3 light = original.rgb * 0.2h;
    const float2 offsets[4] = {major * 24.0, -major * 24.0, minor * 24.0, -minor * 24.0};
    for (int tap = 0; tap < 4; ++tap) {
        half3 sampled = layer.sample(clamp(position + offsets[tap] * scale, safeMin, safeMax)).rgb;
        light += mix(original.rgb, sampled, half(cloudMask(p + offsets[tap]))) * 0.2h;
    }
    half illumination = clamp(dot(light, half3(0.2126h, 0.7152h, 0.0722h)) / 0.65h, 0.08h, 1.4h);
    half4 atmosphere = half4(cloudColor * illumination, 1.0h);
    return mix(original, atmosphere, half(mask));
}
