#include <metal_stdlib>
using namespace metal;

// Stable cell seeds keep the ice stars on their orbits instead of
// regenerating their positions every frame.
static float ringStarSeed(float2 cell) {
    return fract(sin(dot(cell, float2(127.1, 311.7))) * 43758.5453);
}

// Original orthographic planet and ring geometry. There is no baked atmosphere
// beneath this surface: every visible latitude samples the animated cloud map.
[[ stitchable ]] half4 saturnScene(float2 position, half4 input, float2 size,
                                  float time, texture2d<half> clouds) {
    float scale = max(size.x / 1586.0, size.y / 992.0);
    if (scale <= 0.0) return half4(0.0h);
    float2 origin = (size - float2(1586.0, 992.0) * scale) * 0.5;
    float2 p = (position - origin) / scale - float2(1393.0, 420.0);
    const float radius = 553.0;
    const float2 major = float2(0.90044710, -0.43496553);
    const float2 minor = float2(0.43496553, 0.90044710);
    const float tilt = 0.12;
    const float axisCosine = 0.99277389;
    const float3 northAxis = float3(0.0, -axisCosine, tilt);
    const float3 sun = float3(-0.8746, -0.3194, -0.3650);
    float2 q = float2(dot(p, major), dot(p, minor)) / radius;
    float r2 = dot(q, q);
    float aa = 1.25 / (radius * scale);
    float sphereCoverage = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, sqrt(r2));
    float z = sqrt(max(0.0, 1.0 - r2));
    float3 normal = normalize(float3(q, z));
    float3 rgb = float3(0.0);
    float alpha = 0.0;

    // A thin, stationary atmospheric rim. Only the gas texture rotates.
    float limb = exp(-abs(sqrt(r2) - 1.0) * radius / 4.5);
    float glow = limb * 0.13 * smoothstep(-0.12, 0.50, dot(normal, sun));
    rgb = float3(1.0, 0.65, 0.28) * glow;
    alpha = glow;

    if (sphereCoverage > 0.0) {
        float colatitude = acos(clamp(dot(normal, northAxis), -1.0, 1.0));
        float longitude = atan2(normal.x, normal.z * axisCosine + normal.y * tilt);
        float2 uv = float2(longitude / (2.0 * M_PI_F) + 0.5, colatitude / M_PI_F);
        // Every period divides the 5760-second Swift clock wrap.
        const float periods[12] = {18.0, 64.0, 24.0, 48.0, 20.0, 60.0,
                                   30.0, 45.0, 80.0, 72.0, 32.0, 40.0};
        float band = clamp(uv.y * 12.0 - 0.5, 0.0, 11.0);
        int lower = min(int(floor(band)), 10);
        float feather = smoothstep(0.32, 0.68, band - float(lower));
        constexpr sampler cloudSampler(coord::normalized, s_address::repeat,
                                       t_address::clamp_to_edge, filter::linear);
        float3 first = float3(clouds.sample(cloudSampler, uv + float2(time / periods[lower], 0.0)).rgb);
        float3 second = float3(clouds.sample(cloudSampler, uv + float2(time / periods[lower + 1], 0.0)).rgb);
        float3 gas = mix(first, second, feather);
        // Standing north-polar jet, on the same axis as the equator/ring plane.
        float sector = fract((longitude + M_PI_F / 6.0) / (M_PI_F / 3.0)) * (M_PI_F / 3.0) - M_PI_F / 6.0;
        float hexBoundary = 0.255 / cos(sector);
        float jetOffset = (colatitude - hexBoundary) / 0.013;
        float jet = exp(-jetOffset * jetOffset);
        float eye = 1.0 - smoothstep(0.018, 0.050, colatitude);
        float cap = 1.0 - smoothstep(hexBoundary - 0.008, hexBoundary + 0.008, colatitude);
        gas *= mix(float3(1.0), float3(0.48, 0.68, 0.78), cap);
        gas += jet * float3(0.20, 0.22, 0.18);
        gas *= 1.0 - 0.65 * eye;
        float diffuse = max(0.0, dot(normal, sun));
        float light = 0.105 + 1.48 * pow(diffuse, 0.8);
        float3 surface = gas * light * float3(1.08, 0.97, 0.80);
        float rim = pow(1.0 - z, 4.0) * smoothstep(0.0, 0.55, diffuse);
        surface += rim * float3(0.35, 0.19, 0.06);
        // Tiny, silent intracloud flashes. Storm centers advect with their
        // own latitude band; no screen-wide flash or moving illumination.
        float lightning = 0.0;
        for (int storm = 0; storm < 4; ++storm) {
            int latitudeBand = storm + 3;
            float stormLatitude = (float(latitudeBand) + 0.5) / 12.0;
            float stormLongitude = 0.42 + float(storm) * 0.13;
            float advectedLongitude = uv.x + time / periods[latitudeBand];
            float dx = fract(advectedLongitude - stormLongitude + 0.5) - 0.5;
            float2 distance = float2(dx / 0.0035, (uv.y - stormLatitude) / 0.0020);
            float localGlow = exp(-dot(distance, distance));
            float eventTime = fmod(time + float(storm) * 12.0, 48.0);
            float firstPulse = smoothstep(0.0, 0.04, eventTime) * (1.0 - smoothstep(0.08, 0.16, eventTime));
            float secondPulse = smoothstep(0.24, 0.28, eventTime) * (1.0 - smoothstep(0.31, 0.42, eventTime));
            lightning += localGlow * (firstPulse + secondPulse * 0.55);
        }
        surface += lightning * float3(0.65, 0.78, 1.0);
        rgb = surface * sphereCoverage + rgb * (1.0 - sphereCoverage);
        alpha = sphereCoverage + alpha * (1.0 - sphereCoverage);
    }

    // Ray/plane intersection: northAxis · (x,y,z) = 0. The cloud equator
    // and ring share this exact plane, including near/far planet occlusion.
    float ringZ = q.y * axisCosine / tilt;
    float ringRadius = length(float2(q.x, q.y / tilt));
    // Derivatives are evaluated before the coverage branch so edge quads
    // retain defined gradients. Fade frequencies before the Nyquist limit.
    float radialFootprint = max(fwidth(ringRadius), 0.00001);
    float ringAA = aa / tilt;
    float ringCoverage = smoothstep(1.20 - ringAA, 1.20 + ringAA, ringRadius)
        * (1.0 - smoothstep(2.36 - ringAA, 2.36 + ringAA, ringRadius));
    float ringOpacity = 0.0;
    float3 ringColor = float3(0.0);
    if (ringCoverage > 0.0) {
        float front = step(z, ringZ);
        float visible = 1.0 - sphereCoverage * (1.0 - front);
        float gap = smoothstep(1.91, 1.92, ringRadius) * (1.0 - smoothstep(1.97, 1.98, ringRadius));
        float3 frequencies = float3(587.0, 1289.0, 2311.0);
        float3 filter = 1.0 - smoothstep(float3(1.2), float3(M_PI_F), frequencies * radialFootprint);
        float grain = 0.64 + dot(float3(0.17, 0.11, 0.06) * filter, sin(ringRadius * frequencies));
        float density = mix(0.24, 0.88, smoothstep(1.43, 1.51, ringRadius));
        density *= mix(1.0, 0.69, smoothstep(1.99, 2.03, ringRadius));
        float opacity = ringCoverage * visible * density * (0.70 + grain * 0.30) * (1.0 - gap * 0.95);
        ringOpacity = opacity;
        float3 ringPoint = float3(q, ringZ);
        float towardSun = dot(ringPoint, sun);
        float rayDistance = dot(ringPoint, ringPoint) - towardSun * towardSun;
        float shadow = (1.0 - smoothstep(0.94, 1.06, rayDistance)) * (1.0 - step(0.0, towardSun));
        float3 ice = mix(float3(0.46, 0.35, 0.23), float3(1.0, 0.90, 0.70), grain);
        ice *= 0.94 - shadow * 0.82;
        ringColor = ice;
    }

    // Frost occupies the ring and sparse orbits above/below its normal. Each
    // lane has a stable height; nothing bobs while the camera is at rest.
    // Inverse-project each lane before querying its neighboring angular cells,
    // so raised stars remain visible outside the flat ice's coverage mask.
    const float orbitPeriods[4] = {64.0, 80.0, 96.0, 120.0};
    const float pulsePeriods[6] = {3.0, 4.0, 5.0, 6.0, 8.0, 10.0};
    const float radialStep = 1.10 / 8.0;
    const float angularCells = 96.0;
    float frontStarlight = 0.0;
    float backStarlight = 0.0;
    if (abs(q.x) < 2.40 && abs(q.y) < 0.43) {
        for (int layer = -1; layer <= 1; ++layer) {
          for (int lane = 0; lane < 8; ++lane) {
            float height = float(layer) * (0.06 + 0.05 * ringStarSeed(float2(float(lane), float(layer + 3))));
            float2 projected = float2(q.x, (q.y + height * axisCosine) / tilt);
            float projectedRadius = length(projected);
            int nearestLane = int(floor((projectedRadius - 1.24) / radialStep));
            if (abs(nearestLane - lane) > 1) continue;
            float ringAngle = atan2(projected.y, projected.x);
            float turns = time / orbitPeriods[lane / 2];
            float cellAngle = fract(ringAngle / (2.0 * M_PI_F) + turns) * angularCells;
            for (int column = -1; column <= 1; ++column) {
                float cell = fmod(floor(cellAngle) + float(column) + angularCells, angularCells);
                float2 key = float2(float(lane + (layer + 1) * 11), cell);
                float seed = ringStarSeed(key + 0.37);
                if (seed < (layer == 0 ? 0.30 : 0.77)) continue;
                float starRadius = 1.24 + (float(lane) + 0.15 + 0.70 * ringStarSeed(key + 7.9)) * radialStep;
                float orbit = ((cell + 0.15 + 0.70 * ringStarSeed(key + 19.3)) / angularCells - turns) * (2.0 * M_PI_F);
                float3 starPosition = float3(starRadius * cos(orbit),
                    starRadius * tilt * sin(orbit) - height * axisCosine,
                    starRadius * axisCosine * sin(orbit) + height * tilt);
                float2 delta = q - starPosition.xy;
                float2 d = (major * delta.x + minor * delta.y) * radius * scale;
                float distanceSquared = dot(d, d);
                if (distanceSquared > 100.0) continue;
                float planetVisibility = 1.0 - sphereCoverage * (1.0 - step(z, starPosition.z));
                bool behindIce = layer != 0 && starPosition.z < ringZ;
                float towardSun = dot(starPosition, sun);
                float rayDistance = dot(starPosition, starPosition) - towardSun * towardSun;
                float shadow = (1.0 - smoothstep(0.94, 1.06, rayDistance)) * (1.0 - step(0.0, towardSun));
                float prominent = step(0.92, seed);
                float width = mix(0.40, 0.85, ringStarSeed(key + 31.4)) + prominent * 0.25;
                float core = exp(-distanceSquared / (width * width));
                float halo = exp(-distanceSquared / 6.25);
                float rays = exp(-abs(d.x) / 2.5 - d.y * d.y / 0.28)
                           + exp(-abs(d.y) / 2.5 - d.x * d.x / 0.28);
                float pulsePeriod = pulsePeriods[(lane + int(cell)) % 6];
                float sparkle = 0.62 + 0.38 * sin(time * (2.0 * M_PI_F / pulsePeriod) + seed * 19.0);
                float light = (core * (2.5 + prominent * 3.0) + halo * 0.18 + rays * prominent * 0.65)
                    * sparkle * planetVisibility * (1.0 - shadow * 0.8) * 0.65;
                if (behindIce) backStarlight += light;
                else frontStarlight += light;
            }
          }
        }
    }
    // Depth-ordered premultiplied composition: rear frost, ice, front frost.
    // Rear stars never dim the ice in front of them through their own alpha.
    const float3 starColor = float3(1.0, 0.95, 0.82);
    float starAlpha = saturate(backStarlight);
    rgb = backStarlight * starColor + rgb * (1.0 - starAlpha);
    alpha = starAlpha + alpha * (1.0 - starAlpha);
    rgb = ringColor * ringOpacity + rgb * (1.0 - ringOpacity);
    alpha = ringOpacity + alpha * (1.0 - ringOpacity);
    starAlpha = saturate(frontStarlight);
    rgb = frontStarlight * starColor + rgb * (1.0 - starAlpha);
    alpha = starAlpha + alpha * (1.0 - starAlpha);
    return half4(half3(rgb), half(alpha)) * input.a;
}
