// lab09 — 컨볼루션 (필터를 전역 메모리에서 읽는 버전)
// 채울 곳은 커널 안의 // TODO: 한 군데뿐이다. 나머지는 완성된 코드다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"
#include "pgm.h"

// FILTER_RADIUS는 filter_c 배열의 크기를 정하므로 컴파일 시점 상수여야 한다.
// 실행 인자로는 바꿀 수 없고, Makefile이 -DFILTER_RADIUS=n 으로 넘긴다.
#ifndef FILTER_RADIUS
#define FILTER_RADIUS 2
#endif
#define FILTER_DIM (2*FILTER_RADIUS + 1)

// ---------------------------------------------------------------------------
// 슬라이드 11의 커널을, 필터를 전역 메모리에서 읽도록 바꾼 것이다.
// 이 파일에는 상수 메모리 선언이 없다. filter 는 평범한 전역 메모리 배열이고
// 커널 매개변수로 들어온다. 크기는 FILTER_DIM*FILTER_DIM 이고 1차원으로 평탄하다.
// ---------------------------------------------------------------------------
__global__ void convolution_kernel(float* input, float* output, const float* filter,
                                   unsigned int width, unsigned int height) {
    int outRow = blockIdx.y*blockDim.y + threadIdx.y;
    int outCol = blockIdx.x*blockDim.x + threadIdx.x;
    if (outRow < height && outCol < width) {
        float sum = 0.0f;
        for(int filterRow = 0; filterRow < FILTER_DIM; ++filterRow) {
            for(int filterCol = 0; filterCol < FILTER_DIM; ++filterCol) {
                int inRow = outRow - FILTER_RADIUS + filterRow;
                int inCol = outCol - FILTER_RADIUS + filterCol;
                if(inRow >= 0 && inRow < height && inCol >= 0 && inCol < width) {
                    sum += filter[filterRow*FILTER_DIM + filterCol]*input[inRow*width + inCol];
                }
            }
        }
        output[outRow*width + outCol] = sum;
    }

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

// 정규화된 박스 필터. 모든 계수가 1/(FILTER_DIM*FILTER_DIM) 이라 결과가 평균이 된다.
static void make_box_filter(float* filter) {
    float w = 1.0f/(float)(FILTER_DIM*FILTER_DIM);
    for (int i = 0; i < FILTER_DIM*FILTER_DIM; ++i) filter[i] = w;
}

// CPU 참조 컨볼루션. 커널과 같은 경계 처리를 쓴다.
static void convolution_cpu(const float* input, const float* filter, float* output,
                            unsigned int width, unsigned int height) {
    for (int outRow = 0; outRow < (int)height; ++outRow) {
        for (int outCol = 0; outCol < (int)width; ++outCol) {
            float sum = 0.0f;
            for (int filterRow = 0; filterRow < FILTER_DIM; ++filterRow) {
                for (int filterCol = 0; filterCol < FILTER_DIM; ++filterCol) {
                    int inRow = outRow - FILTER_RADIUS + filterRow;
                    int inCol = outCol - FILTER_RADIUS + filterCol;
                    if (inRow >= 0 && inRow < (int)height && inCol >= 0 && inCol < (int)width) {
                        sum += filter[filterRow*FILTER_DIM + filterCol]*input[inRow*width + inCol];
                    }
                }
            }
            output[outRow*width + outCol] = sum;
        }
    }
}

// 큰 이미지에서는 CPU로 전체를 다시 계산하기에 너무 느리다.
// 그때는 무작위로 고른 픽셀만 CPU로 직접 구해 대조한다.
// 메시지 형식과 오차 기준은 compare_float과 같다.
static int spot_check(const float* input, const float* filter, const float* output,
                      unsigned int width, unsigned int height,
                      unsigned int samples, float tol) {
    double sq = 0.0;
    size_t n = (size_t)width*height;
    for (size_t k = 0; k < n; ++k) sq += (double)output[k]*output[k];
    float scale = (float)sqrt(sq/(double)n);
    if (scale < 1e-6f) scale = 1e-6f;

    unsigned int s = 12345u;
    for (unsigned int t = 0; t < samples; ++t) {
        s = s*1664525u + 1013904223u;  int outRow = (int)((s >> 8) % height);
        s = s*1664525u + 1013904223u;  int outCol = (int)((s >> 8) % width);

        float sum = 0.0f;
        for (int filterRow = 0; filterRow < FILTER_DIM; ++filterRow) {
            for (int filterCol = 0; filterCol < FILTER_DIM; ++filterCol) {
                int inRow = outRow - FILTER_RADIUS + filterRow;
                int inCol = outCol - FILTER_RADIUS + filterCol;
                if (inRow >= 0 && inRow < (int)height && inCol >= 0 && inCol < (int)width) {
                    sum += filter[filterRow*FILTER_DIM + filterCol]*input[inRow*width + inCol];
                }
            }
        }
        float got = output[outRow*width + outCol];
        float rel = fabsf(sum - got)/scale;
        if (rel > tol || isnan(got)) {
            printf("  첫 불일치: [%zu]  기대 %.6f  실제 %.6f  (오차/기준크기 %.3e)\n",
                   (size_t)outRow*width + outCol, sum, got, rel);
            return 0;
        }
    }
    return 1;
}

int main(int argc, char** argv) {

    unsigned int width  = (argc > 1) ? (unsigned int)atoi(argv[1]) : 4096;
    unsigned int height = (argc > 2) ? (unsigned int)atoi(argv[2]) : 4096;

    if (width == 0 || height == 0) {
        fprintf(stderr, "width와 height는 1 이상이어야 한다\n");
        return 1;
    }

    // input.pgm이 있으면 그것을 쓰고, 없으면 합성 이미지를 만든다.
    unsigned char* image = read_pgm("input.pgm", &width, &height);
    if (image) {
        printf("입력: input.pgm (%u x %u)\n", width, height);
    } else {
        if (pgm_file_exists("input.pgm")) {
            fprintf(stderr, "input.pgm을 읽을 수 없다. 8비트 회색조 P5(PGM)만 지원한다.\n");
            fprintf(stderr, "합성 이미지로 대신 진행한다.\n");
        }
        image = (unsigned char*)malloc((size_t)width*height);
        make_test_image(image, width, height);
        printf("입력: 합성 사선 무늬 (%u x %u)\n", width, height);
    }
    printf("FILTER_RADIUS = %d  (FILTER_DIM = %d)\n", FILTER_RADIUS, FILTER_DIM);

    size_t n     = (size_t)width*height;
    size_t bytes = n*sizeof(float);

    float* input   = (float*)malloc(bytes);
    float* output  = (float*)malloc(bytes);
    float* filter  = (float*)malloc((size_t)FILTER_DIM*FILTER_DIM*sizeof(float));
    for (size_t k = 0; k < n; ++k) input[k] = (float)image[k];
    make_box_filter(filter);

    size_t filter_bytes = (size_t)FILTER_DIM*FILTER_DIM*sizeof(float);

    float *input_d, *output_d, *filter_d;
    CUDA_CHECK(cudaMalloc((void**) &input_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &output_d, bytes));
    CUDA_CHECK(cudaMemcpy(input_d, input, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(output_d, 0, bytes));

    // 필터를 전역 메모리에 올린다. 상수 메모리를 쓰지 않는다.
    CUDA_CHECK(cudaMalloc((void**) &filter_d, filter_bytes));
    CUDA_CHECK(cudaMemcpy(filter_d, filter, filter_bytes, cudaMemcpyHostToDevice));

    dim3 block(16, 16);
    dim3 grid((width + block.x - 1)/block.x, (height + block.y - 1)/block.y);
    Timer timer;

    // 한 번 예열한 뒤 측정한다
    convolution_kernel<<<grid, block>>>(input_d, output_d, filter_d, width, height);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    timer.start();
    convolution_kernel<<<grid, block>>>(input_d, output_d, filter_d, width, height);
    float ms = timer.stop();
    CUDA_CHECK(cudaMemcpy(output, output_d, bytes, cudaMemcpyDeviceToHost));

    // 정확성 — 작으면 전체를 CPU로 다시 계산하고, 크면 무작위 표본만 대조한다.
    int ok;
    if (n <= 1024u*1024u) {
        float* ref = (float*)malloc(bytes);
        convolution_cpu(input, filter, ref, width, height);
        ok = compare_float(ref, output, n, 1e-3f);
        free(ref);
    } else {
        ok = spot_check(input, filter, output, width, height, 4096, 1e-3f);
    }

    // 유효 대역폭은 최소 트래픽 기준이다. 출력 픽셀 하나당 입력 4바이트를 한 번 읽고
    // 출력 4바이트를 한 번 쓴다고 본다. 필터 크기만큼 겹쳐 읽는 부분은 캐시가
    // 흡수하라고 있는 것이므로 세지 않는다 (lab12의 유효 대역폭과 같은 기준).
    // 연산은 탭마다 곱 1 + 합 1 이므로 출력 픽셀당 2*FILTER_DIM*FILTER_DIM FLOP이다.
    double pixels = (double)n;
    double traffic_bytes = pixels*2.0*sizeof(float);
    double flop = pixels*2.0*FILTER_DIM*FILTER_DIM;
    double sec  = ms/1e3;

    // 슬라이드 20의 비율은 계산 기준이 다르다. 커널이 실제로 요청하는 전역 접근을
    // 그대로 센다. 이 버전은 탭마다 입력 4바이트와 필터 4바이트를 함께 읽으므로
    // 2*D^2 FLOP / (8*D^2 + 4) 바이트다. 상수 메모리 버전보다 분모가 두 배다.
    double slide20 = (2.0*FILTER_DIM*FILTER_DIM)/(8.0*FILTER_DIM*FILTER_DIM + 4.0);

    printf("커널        : %8.2f ms\n", ms);
    printf("유효 대역폭 : %8.1f GB/s\n", traffic_bytes/sec/1e9);
    printf("연산 처리율 : %8.1f GFLOP/s\n", flop/sec/1e9);
    printf("연산/바이트 : %8.1f FLOP/B  (최소 트래픽 기준)\n", flop/traffic_bytes);
    printf("슬라이드 20 : %8.2f FLOP/B  (필터도 전역에서 읽는다)\n", slide20);
    printf("정확성: %s\n", ok ? "PASS" : "FAIL");

    // 결과를 이미지로도 남긴다.
    unsigned char* out_image = (unsigned char*)malloc(n);
    for (size_t k = 0; k < n; ++k) {
        float v = output[k];
        if (v < 0.0f) v = 0.0f;
        if (v > 255.0f) v = 255.0f;
        out_image[k] = (unsigned char)(v + 0.5f);
    }
    if (!write_pgm("out.pgm", out_image, width, height)) {
        fprintf(stderr, "out.pgm 저장 실패\n");
    }
    free(out_image);

    free(image); free(input); free(output); free(filter);
    CUDA_CHECK(cudaFree(input_d)); CUDA_CHECK(cudaFree(output_d));
    CUDA_CHECK(cudaFree(filter_d));
    return ok ? 0 : 1;
}
