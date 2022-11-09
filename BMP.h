#ifndef CBMP_BMP_H
#define CBMP_BMP_H

#ifndef __cplusplus

    #include <stdbool.h>
    #include <stdint.h>

#endif

#ifdef __cplusplus
    #include <cstdint>

    extern "C" {
#endif
#pragma pack(1)
struct BMP
{
    bool initialised;       //private - not to be modified manually
    unsigned int width;
    unsigned int height;
    unsigned int bitDepth;
    uint8_t **R;
    uint8_t **G;
    uint8_t **B;
    uint8_t **A;
};

typedef enum
{
    Red,
    Green,
    Blue,
    Alpha
} RGBA;

char *addExtension(const char* fileName);
unsigned int swapEndianness4(unsigned int);
unsigned int swapEndianness2(unsigned int);
unsigned int mergeBytes(const uint8_t* array, int start, int num);
int *digestColourTable(uint8_t* colourTable);
void encode(char* str, unsigned int* position, unsigned int number, int bytes);

extern struct BMP* init();
extern int open(struct BMP*, const char* fileName);
extern void close(struct BMP*);
extern int exportBMP(const struct BMP*, const char* fileName);

extern void setSize(struct BMP*, unsigned int width, unsigned int height);
extern int setBitDepth(struct BMP*, unsigned int bitDepth);

#ifdef __cplusplus
}
#endif

#pragma GCC poison initialised
#endif //CBMP_BMP_H