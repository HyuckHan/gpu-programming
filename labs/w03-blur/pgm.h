// PGM(P5) 이미지 입출력과 터미널 미리보기.
// blur.cu와 blur_naive.cu가 함께 쓴다. 외부 라이브러리를 쓰지 않는다.
#ifndef PGM_H
#define PGM_H

#include <stdio.h>
#include <stdlib.h>

// PGM 헤더에서 다음 정수 하나를 읽는다. 공백과 주석(#)은 건너뛴다.
static int pgm_next_int(FILE* f, unsigned int* out) {
    int c;
    do {
        c = fgetc(f);
        if (c == '#') {                       // 주석은 줄 끝까지 버린다
            while (c != '\n' && c != EOF) c = fgetc(f);
        }
    } while (c == ' ' || c == '\t' || c == '\n' || c == '\r');
    if (c == EOF) return 0;
    ungetc(c, f);
    return fscanf(f, "%u", out) == 1;
}

// P5 파일을 읽어 픽셀 배열을 돌려준다. 실패하면 NULL.
// 성공하면 width, height에 이미지 크기가 담긴다. 호출한 쪽이 free 해야 한다.
static unsigned char* read_pgm(const char* path, unsigned int* width, unsigned int* height) {
    FILE* f = fopen(path, "rb");
    if (!f) return NULL;

    char magic[3] = {0};
    if (fscanf(f, "%2s", magic) != 1 || magic[0] != 'P' || magic[1] != '5') {
        fclose(f);
        return NULL;
    }

    unsigned int w = 0, h = 0, maxval = 0;
    if (!pgm_next_int(f, &w) || !pgm_next_int(f, &h) || !pgm_next_int(f, &maxval)
        || w == 0 || h == 0 || maxval != 255) {
        fclose(f);
        return NULL;
    }
    fgetc(f);                                  // 헤더와 픽셀 사이의 공백 한 칸

    unsigned char* image = (unsigned char*)malloc((size_t)w*h);
    if (!image) { fclose(f); return NULL; }
    if (fread(image, 1, (size_t)w*h, f) != (size_t)w*h) {
        free(image);
        fclose(f);
        return NULL;
    }
    fclose(f);

    *width  = w;
    *height = h;
    return image;
}

// 픽셀 배열을 P5 파일로 저장한다. 성공하면 1.
static int write_pgm(const char* path, const unsigned char* image,
                     unsigned int width, unsigned int height) {
    FILE* f = fopen(path, "wb");
    if (!f) return 0;
    fprintf(f, "P5\n%u %u\n255\n", width, height);
    size_t n = fwrite(image, 1, (size_t)width*height, f);
    fclose(f);
    return n == (size_t)width*height;
}

// 입력 파일이 없을 때 쓰는 합성 이미지. 16픽셀 폭의 사선 무늬다.
// 명암 경계가 뚜렷해서 흐림 처리 뒤 가장자리 손상이 눈에 잘 띈다.
// 6픽셀 어긋나게 시작해서 좌상단 8x8 미리보기 안으로 줄 경계가 들어오게 했다.
static void make_test_image(unsigned char* image, unsigned int width, unsigned int height) {
    for (unsigned int row = 0; row < height; ++row) {
        for (unsigned int col = 0; col < width; ++col) {
            image[row*width + col] = ((((row + col) + 6)/16) % 2) ? 255 : 0;
        }
    }
}

// 좌상단 8x8 픽셀값을 정수로 찍는다. 이미지 뷰어 없이 결과를 확인하는 용도다.
static void print_preview(const char* label, const unsigned char* image,
                          unsigned int width, unsigned int height) {
    unsigned int rows = (height < 8) ? height : 8;
    unsigned int cols = (width  < 8) ? width  : 8;
    printf("%s (좌상단 %ux%u):\n", label, rows, cols);
    for (unsigned int row = 0; row < rows; ++row) {
        for (unsigned int col = 0; col < cols; ++col) {
            printf(" %3u", image[row*width + col]);
        }
        printf("\n");
    }
}

#endif // PGM_H
