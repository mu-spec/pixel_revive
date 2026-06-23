#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uBrightness; // -1.0 to 1.0 (0.0 is default)
uniform float uContrast;   // 0.0 to 3.0 (1.0 is default)
uniform float uSaturation; // 0.0 to 3.0 (1.0 is default)
uniform float uSharpen;    // 0.0 to 2.0 (0.0 is default)
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
    // 1. Get normalized texture coordinates (uv)
    vec2 uv = FlutterFragCoord().xy / uSize;
    
    // 2. Fetch the source pixel
    vec4 color = texture(uTexture, uv);
    
    // 3. Apply Sharpen (Laplacian filter kernel approximation in shader)
    if (uSharpen > 0.01) {
        vec2 texel = 1.0 / uSize;
        vec4 sum = vec4(0.0);
        
        // 3x3 Sharpen Kernel:
        //  0  -1   0
        // -1   5  -1
        //  0  -1   0
        vec4 cUp    = texture(uTexture, uv + vec2(0.0, -texel.y));
        vec4 cDown  = texture(uTexture, uv + vec2(0.0, texel.y));
        vec4 cLeft  = texture(uTexture, uv + vec2(-texel.x, 0.0));
        vec4 cRight = texture(uTexture, uv + vec2(texel.x, 0.0));
        
        vec4 edgeDetails = (color * 5.0) - (cUp + cDown + cLeft + cRight);
        color = mix(color, edgeDetails, uSharpen);
    }

    // 4. Adjust Brightness
    color.rgb += uBrightness;

    // 5. Adjust Contrast
    color.rgb = (color.rgb - vec3(0.5)) * uContrast + vec3(0.5);

    // 6. Adjust Saturation (using standard NTSC weights)
    float luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(vec3(luma), color.rgb, uSaturation);

    // Ensure color stays clamped in bounds
    fragColor = vec4(clamp(color.rgb, 0.0, 1.0), color.a);
}
