// {{{ image_info
// C utility for extracting basic image metadata
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// {{{ get_png_info
int get_png_info(const char* filename, int* width, int* height) {
    FILE* file = fopen(filename, "rb");
    if (!file) return -1;
    
    // Check PNG signature
    uint8_t signature[8];
    if (fread(signature, 1, 8, file) != 8) {
        fclose(file);
        return -1;
    }
    
    uint8_t png_sig[8] = {0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A};
    for (int i = 0; i < 8; i++) {
        if (signature[i] != png_sig[i]) {
            fclose(file);
            return -1;
        }
    }
    
    // Read IHDR chunk
    uint32_t chunk_length;
    char chunk_type[5] = {0};
    
    if (fread(&chunk_length, 4, 1, file) != 1 ||
        fread(chunk_type, 1, 4, file) != 4) {
        fclose(file);
        return -1;
    }
    
    if (strcmp(chunk_type, "IHDR") != 0) {
        fclose(file);
        return -1;
    }
    
    uint32_t w, h;
    if (fread(&w, 4, 1, file) != 1 || fread(&h, 4, 1, file) != 1) {
        fclose(file);
        return -1;
    }
    
    // Convert from big-endian
    *width = ((w & 0xFF) << 24) | (((w >> 8) & 0xFF) << 16) | 
             (((w >> 16) & 0xFF) << 8) | ((w >> 24) & 0xFF);
    *height = ((h & 0xFF) << 24) | (((h >> 8) & 0xFF) << 16) | 
              (((h >> 16) & 0xFF) << 8) | ((h >> 24) & 0xFF);
    
    fclose(file);
    return 0;
}
// }}}

// {{{ get_jpeg_info
int get_jpeg_info(const char* filename, int* width, int* height) {
    FILE* file = fopen(filename, "rb");
    if (!file) return -1;
    
    // Check JPEG signature
    uint8_t marker[2];
    if (fread(marker, 1, 2, file) != 2 || marker[0] != 0xFF || marker[1] != 0xD8) {
        fclose(file);
        return -1;
    }
    
    while (1) {
        if (fread(marker, 1, 2, file) != 2) break;
        
        if (marker[0] != 0xFF) continue;
        
        // SOF0 or SOF2 markers
        if (marker[1] == 0xC0 || marker[1] == 0xC2) {
            uint16_t length;
            uint8_t precision;
            uint16_t h, w;
            
            fread(&length, 2, 1, file);
            fread(&precision, 1, 1, file);
            fread(&h, 2, 1, file);
            fread(&w, 2, 1, file);
            
            // Convert from big-endian
            *height = (h >> 8) | (h << 8);
            *width = (w >> 8) | (w << 8);
            
            fclose(file);
            return 0;
        }
        
        // Skip other chunks
        uint16_t chunk_size;
        if (fread(&chunk_size, 2, 1, file) != 1) break;
        chunk_size = (chunk_size >> 8) | (chunk_size << 8);
        fseek(file, chunk_size - 2, SEEK_CUR);
    }
    
    fclose(file);
    return -1;
}
// }}}

// {{{ main
int main(int argc, char* argv[]) {
    if (argc != 2) {
        fprintf(stderr, "Usage: %s <image_file>\n", argv[0]);
        return 1;
    }
    
    const char* filename = argv[1];
    const char* ext = strrchr(filename, '.');
    int width = 0, height = 0;
    int result = -1;
    
    if (ext) {
        if (strcasecmp(ext, ".png") == 0) {
            result = get_png_info(filename, &width, &height);
        } else if (strcasecmp(ext, ".jpg") == 0 || strcasecmp(ext, ".jpeg") == 0) {
            result = get_jpeg_info(filename, &width, &height);
        }
    }
    
    if (result == 0) {
        printf("width:%d\n", width);
        printf("height:%d\n", height);
        printf("format:%s\n", ext + 1);
        
        // Basic analysis
        float aspect_ratio = (float)width / height;
        if (aspect_ratio > 1.2) {
            printf("orientation:landscape\n");
        } else if (aspect_ratio < 0.8) {
            printf("orientation:portrait\n");
        } else {
            printf("orientation:square\n");
        }
        
        if (width >= 1920 && height >= 1080) {
            printf("resolution:high\n");
        } else if (width >= 512 && height >= 512) {
            printf("resolution:medium\n");
        } else {
            printf("resolution:low\n");
        }
        
        return 0;
    } else {
        fprintf(stderr, "Error: Could not analyze image %s\n", filename);
        return 1;
    }
}
// }}}
// }}}