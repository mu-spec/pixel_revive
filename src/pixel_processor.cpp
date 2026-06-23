#include <cmath>
#include <algorithm>
#include <stdint.h>

#ifdef _WIN32
#define FFI_EXPORT __declspec(dllexport)
#else
#define FFI_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

extern "C" {

// =========================================================================
// HIGH-SPEED NATIVE BILATERAL DENOISE FILTER (Contiguous memory execution)
// =========================================================================
FFI_EXPORT void native_denoise(
    const uint8_t* src,
    uint8_t* dest,
    int width,
    int height,
    float sigmaR
) {
    const float sigmaR2 = 2.0f * sigmaR * sigmaR;
    
    // Process every pixel except boundary padding
    for (int y = 1; y < height - 1; ++y) {
        for (int x = 1; x < width - 1; ++x) {
            int centerIdx = (y * width + x) * 4;
            
            float centerR = src[centerIdx];
            float centerG = src[centerIdx + 1];
            float centerB = src[centerIdx + 2];
            float centerA = src[centerIdx + 3];

            float sumR = 0, sumG = 0, sumB = 0;
            float totalWeight = 0;

            // 3x3 pixel neighborhood kernel
            for (int ky = -1; ky <= 1; ++ky) {
                for (int kx = -1; kx <= 1; ++kx) {
                    int neighborIdx = ((y + ky) * width + (x + kx)) * 4;
                    
                    float nR = src[neighborIdx];
                    float nG = src[neighborIdx + 1];
                    float nB = src[neighborIdx + 2];

                    // Spatial distance weight (Gaussian simplified)
                    float spaceWeight = (kx == 0 && ky == 0) ? 1.0f : 0.61f;

                    // Range (Color distance) weight calculation
                    float diffR = centerR - nR;
                    float diffG = centerG - nG;
                    float diffB = centerB - nB;
                    float colorDist2 = (diffR * diffR) + (diffG * diffG) + (diffB * diffB);
                    
                    float rangeWeight = expf(-colorDist2 / sigmaR2);
                    float weight = spaceWeight * rangeWeight;

                    sumR += nR * weight;
                    sumG += nG * weight;
                    sumB += nB * weight;
                    totalWeight += weight;
                }
            }

            // Write results with clamp checks directly back to destination memory
            dest[centerIdx]     = static_cast<uint8_t>(std::min(std::max(sumR / totalWeight, 0.0f), 255.0f));
            dest[centerIdx + 1] = static_cast<uint8_t>(std::min(std::max(sumG / totalWeight, 0.0f), 255.0f));
            dest[centerIdx + 2] = static_cast<uint8_t>(std::min(std::max(sumB / totalWeight, 0.0f), 255.0f));
            dest[centerIdx + 3] = static_cast<uint8_t>(centerA); // Keep alpha intact
        }
    }

    // Copy boundaries
    for (int x = 0; x < width; ++x) {
        int topIdx = x * 4;
        int botIdx = ((height - 1) * width + x) * 4;
        for (int i = 0; i < 4; ++i) {
            dest[topIdx + i] = src[topIdx + i];
            dest[botIdx + i] = src[botIdx + i];
        }
    }
    for (int y = 0; y < height; ++y) {
        int leftIdx = y * width * 4;
        int rightIdx = (y * width + (width - 1)) * 4;
        for (int i = 0; i < 4; ++i) {
            dest[leftIdx + i] = src[leftIdx + i];
            dest[rightIdx + i] = src[rightIdx + i];
        }
    }
}

// =========================================================================
// HIGH-SPEED NATIVE SHARPENING FILTER (Laplacian / Unsharp mask kernel)
// =========================================================================
FFI_EXPORT void native_sharpen(
    const uint8_t* src,
    uint8_t* dest,
    int width,
    int height,
    float strength
) {
    for (int y = 1; y < height - 1; ++y) {
        for (int x = 1; x < width - 1; ++x) {
            int idx = (y * width + x) * 4;
            
            // Apply 3x3 Lapalcian Sharpen operator
            for (int channel = 0; channel < 3; ++channel) {
                int centerVal = src[idx + channel];
                
                int topVal   = src[((y - 1) * width + x) * 4 + channel];
                int bottomVal= src[((y + 1) * width + x) * 4 + channel];
                int leftVal  = src[(y * width + (x - 1)) * 4 + channel];
                int rightVal = src[(y * width + (x + 1)) * 4 + channel];

                // Laplacian edge computation: Center * 5 - (Neighbors)
                float sharpened = (centerVal * 5.0f) - (topVal + bottomVal + leftVal + rightVal);
                
                // Blend original pixel with sharpened edge based on strength
                float finalVal = centerVal + (sharpened - centerVal) * strength;
                
                dest[idx + channel] = static_cast<uint8_t>(std::min(std::max(finalVal, 0.0f), 255.0f));
            }
            dest[idx + 3] = src[idx + 3]; // Copy Alpha
        }
    }

    // Copy boundaries
    for (int x = 0; x < width; ++x) {
        int topIdx = x * 4;
        int botIdx = ((height - 1) * width + x) * 4;
        for (int i = 0; i < 4; ++i) {
            dest[topIdx + i] = src[topIdx + i];
            dest[botIdx + i] = src[botIdx + i];
        }
    }
    for (int y = 0; y < height; ++y) {
        int leftIdx = y * width * 4;
        int rightIdx = (y * width + (width - 1)) * 4;
        for (int i = 0; i < 4; ++i) {
            dest[leftIdx + i] = src[leftIdx + i];
            dest[rightIdx + i] = src[rightIdx + i];
        }
    }
}

}
