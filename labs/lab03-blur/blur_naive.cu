// 3주차 — blur (관찰용)
// 이 프로그램은 컴파일되고 실행도 된다. 출력을 관찰하는 것이 과제다.
#include <stdio.h>
#include <stdlib.h>
#include "../../common/common.cuh"
#include "pgm.h"

// ---------------------------------------------------------------------------
// 슬라이드 17 — Chapter 03, Example: Blur
// BLUR_SIZE만 실행 인자로 받기 위해 커널 매개변수로 옮겼다.
// ---------------------------------------------------------------------------
__global__ void blur_kernel(unsigned char* image, unsigned char* blurred,
                            unsigned int width, unsigned int height, int BLUR_SIZE) {

    int outRow = blockIdx.y*blockDim.y + threadIdx.y;
    int outCol = blockIdx.x*blockDim.x + threadIdx.x;

    if (outRow < height && outCol < width) {

        unsigned int average = 0;
        for(int inRow = outRow - BLUR_SIZE; inRow < outRow + BLUR_SIZE + 1; ++inRow) {
            for(int inCol = outCol - BLUR_SIZE; inCol < outCol + BLUR_SIZE + 1; ++inCol) {
                average += image[inRow*width + inCol];
            }
        }
        blurred[outRow*width + outCol] =
                      (unsigned char)(average/((2*BLUR_SIZE + 1)*(2*BLUR_SIZE + 1)));

    }

}

// ---------------------------------------------------------------------------
// 호스트 코드
// ---------------------------------------------------------------------------

// CPU 참조 blur. 정확한 결과를 만드는 기준이다.
static void blur_cpu(const unsigned char* image, unsigned char* blurred,
                     unsigned int width, unsigned int height, int BLUR_SIZE) {
    for (int outRow = 0; outRow < (int)height; ++outRow) {
        for (int outCol = 0; outCol < (int)width; ++outCol) {
            unsigned int average = 0;
            unsigned int count = 0;
            for (int inRow = outRow - BLUR_SIZE; inRow < outRow + BLUR_SIZE + 1; ++inRow) {
                for (int inCol = outCol - BLUR_SIZE; inCol < outCol + BLUR_SIZE + 1; ++inCol) {
                    if (inRow >= 0 && inRow < (int)height && inCol >= 0 && inCol < (int)width) {
                        average += image[inRow*width + inCol];
                        count++;
                    }
                }
            }
            blurred[outRow*width + outCol] = (unsigned char)(average/count);
        }
    }
}

int main(int argc, char** argv) {

    unsigned int width  = (argc > 1) ? (unsigned int)atoi(argv[1]) : 512;
    unsigned int height = (argc > 2) ? (unsigned int)atoi(argv[2]) : 512;
    int BLUR_SIZE       = (argc > 3) ? atoi(argv[3]) : 1;

    if (width == 0 || height == 0) {
        fprintf(stderr, "width와 height는 1 이상이어야 한다\n");
        return 1;
    }
    if (BLUR_SIZE < 1) {
        fprintf(stderr, "BLUR_SIZE는 1 이상이어야 한다 (받은 값: %d)\n", BLUR_SIZE);
        return 1;
    }

    // input.pgm이 있으면 그것을 쓰고, 없으면 합성 이미지를 만든다.
    unsigned char* image = read_pgm("input.pgm", &width, &height);
    if (image) {
        printf("입력: input.pgm (%u x %u)\n", width, height);
    } else {
        // 파일이 있는데도 못 읽었다면 형식 문제다. 조용히 넘어가지 않는다.
        if (pgm_file_exists("input.pgm")) {
            fprintf(stderr, "input.pgm을 읽을 수 없다. 8비트 회색조 P5(PGM)만 지원한다.\n");
            fprintf(stderr, "합성 이미지로 대신 진행한다.\n");
        }
        image = (unsigned char*)malloc((size_t)width*height);
        make_test_image(image, width, height);
        printf("입력: 합성 사선 무늬 (%u x %u)\n", width, height);
    }
    printf("BLUR_SIZE = %d\n\n", BLUR_SIZE);

    size_t bytes = (size_t)width*height;
    unsigned char* blurred_gpu = (unsigned char*)malloc(bytes);
    unsigned char* blurred_cpu = (unsigned char*)malloc(bytes);

    blur_cpu(image, blurred_cpu, width, height, BLUR_SIZE);

    unsigned char *image_d, *blurred_d;
    CUDA_CHECK(cudaMalloc((void**) &image_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &blurred_d, bytes));
    CUDA_CHECK(cudaMemcpy(image_d, image, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(blurred_d, 0, bytes));

    dim3 block(16, 16);
    dim3 grid((width + block.x - 1)/block.x, (height + block.y - 1)/block.y);

    blur_kernel<<<grid, block>>>(image_d, blurred_d, width, height, BLUR_SIZE);

    // 여기서는 CUDA_CHECK로 즉시 종료하지 않는다. 커널이 실패하더라도
    // 미리보기까지는 보여주고 정상 종료해야 하기 때문이다.
    cudaError_t kernel_err = cudaDeviceSynchronize();

    print_preview("입력", image, width, height);
    printf("\n");

    if (kernel_err == cudaSuccess) {
        CUDA_CHECK(cudaMemcpy(blurred_gpu, blurred_d, bytes, cudaMemcpyDeviceToHost));
        print_preview("GPU 출력", blurred_gpu, width, height);
        printf("\n");
    } else {
        printf("GPU 출력: 없음 — 커널이 끝까지 실행되지 못했다\n");
        printf("  %s\n\n", cudaGetErrorString(kernel_err));
    }

    print_preview("CPU 참조", blurred_cpu, width, height);
    printf("\n");

    int ok = (kernel_err == cudaSuccess) && compare_bytes(blurred_cpu, blurred_gpu, bytes);
    printf("검증: %s\n", ok ? "PASS" : "FAIL");

    if (kernel_err == cudaSuccess) {
        if (write_pgm("out.pgm", blurred_gpu, width, height)) {
            printf("결과를 out.pgm 으로 저장했다\n");
        } else {
            fprintf(stderr, "out.pgm 저장 실패\n");
        }
    }

    free(image); free(blurred_gpu); free(blurred_cpu);
    // 커널이 실패했다면 컨텍스트가 이미 무효라 cudaFree도 실패한다. 확인하지 않는다.
    cudaFree(image_d); cudaFree(blurred_d);
    return 0;
}
