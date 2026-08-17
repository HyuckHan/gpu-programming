// lab10 — 히스토그램과 데이터 경쟁
// 채울 곳은 histogram_atomic_kernel 과 histogram_private_kernel 두 군데다.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.cuh"

#define NUM_BINS  256
#define BLOCK_DIM 256

// --skewed 일 때 값의 80%를 여기 적은 칸 수 안에 몰아 넣는다.
// 이 값을 크게 잡으면 오히려 atomic 이 빨라진다. 워프 안에서 같은 칸을 노린
// atomic 은 하드웨어가 하나로 합쳐 주는데, 칸이 적당히 흩어져 있으면 그 이득과
// 경합 분산 이득이 겹치기 때문이다. 실측으로 16칸이 균등보다 빨랐다.
// 경합이 실제로 비싸지는 것을 보이려면 몇 칸 안 되게 몰아야 한다.
#define SKEW_BINS 4

// ---------------------------------------------------------------------------
// 슬라이드 3 / 슬라이드 12 왼쪽 (완성)
// ---------------------------------------------------------------------------
__global__ void histogram_race_kernel(unsigned char* image, unsigned int* bins,
                                      unsigned int width, unsigned int height) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(i < width*height) {
        unsigned char b = image[i];
        ++bins[b];
    }

}

// ---------------------------------------------------------------------------
// 슬라이드 12 오른쪽 — 여기를 채운다
//
// 위 커널과 다른 곳은 딱 한 줄이다.
// ---------------------------------------------------------------------------
__global__ void histogram_atomic_kernel(unsigned char* image, unsigned int* bins,
                                        unsigned int width, unsigned int height) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(i < width*height) {
        unsigned char b = image[i];

        // TODO: bins[b] 를 1 늘린다. 다만 여러 스레드가 같은 칸을 동시에 건드려도
        //       증가가 사라지지 않아야 한다. 슬라이드 12 오른쪽 코드다.

    }

}

// ---------------------------------------------------------------------------
// 슬라이드 14, 15, 17 — privatization. 여기를 채운다
//
// 이 커널은 슬라이드에 코드가 없다. 개념 설명을 보고 직접 구현하는 것이 과제다.
// 생각의 순서는 이렇다. 전역 bins 하나를 온 블록이 두들기는 대신,
// 블록마다 자기 사본을 공유 메모리에 두고 거기서 먼저 세고,
// 다 센 뒤에 사본을 전역에 한 번만 합친다.
//
// NUM_BINS 는 256이라 공유 메모리로 1KB뿐이다. 여유가 충분하다.
// ---------------------------------------------------------------------------
// privatization — 도전 과제, 선택
//
// 이 커널은 슬라이드에 코드가 없다. 개념 설명(슬라이드 14·15·17)을 보고
// 직접 구현하는 것이다. 못 채워도 이 랩은 통과한다. verify.py 는 위의
// atomic 커널만 판정한다.
// ---------------------------------------------------------------------------
__global__ void histogram_private_kernel(unsigned char* image, unsigned int* bins,
                                         unsigned int width, unsigned int height) {

    __shared__ unsigned int bins_s[NUM_BINS];

    // TODO 1: bins_s 를 0으로 초기화한다.
    //         블록의 스레드로 나눠서 하라. 스레드 0 혼자 256번 돌면
    //         그 부분이 그대로 병목이 된다.

    // TODO 2: 초기화가 끝날 때까지 블록 안 모든 스레드가 기다린다

    // TODO 3: 자기가 맡은 원소를 읽어 bins_s 에 더한다.
    //         i 를 구하는 식과 경계 검사는 위 두 커널과 같다.

    // TODO 4: 블록 안 모든 스레드가 세기를 끝낼 때까지 기다린다

    // TODO 5: bins_s 의 각 칸을 전역 bins 에 반영한다.
    //         이것도 블록의 스레드로 나눠서 하라.

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

#define NUM_KERNELS 3
static const char* KERNEL_NAMES[NUM_KERNELS] = { "race", "atomic", "private" };

// 입력을 만든다. 시드가 같으면 항상 같은 값이 나온다.
//   균등  — 0~255 가 고르게 나온다
//   치우침 — 값의 80%가 SKEW_BINS 칸에 몰린다. 같은 칸을 노리는 스레드가
//            많아지므로 atomic 의 경합이 심해진다.
static void init_image(unsigned char* image, size_t n, unsigned int seed, int skewed) {
    unsigned int s = seed;
    for (size_t i = 0; i < n; ++i) {
        s = s*1664525u + 1013904223u;                  // 선형 합동 생성기
        if (skewed) {
            unsigned int pick = (s >> 8) % 100;
            s = s*1664525u + 1013904223u;
            image[i] = (pick < 80) ? (unsigned char)((s >> 8) % SKEW_BINS)
                                   : (unsigned char)((s >> 8) % NUM_BINS);
        } else {
            image[i] = (unsigned char)((s >> 24) & 0xFF);
        }
    }
}

// CPU 참조. 그냥 순서대로 센다.
static void histogram_cpu(const unsigned char* image, size_t n, unsigned int* bins) {
    memset(bins, 0, NUM_BINS*sizeof(unsigned int));
    for (size_t i = 0; i < n; ++i) {
        unsigned char b = image[i];
        ++bins[b];
    }
}

// bin 은 정수라 허용오차가 없다. 한 칸이라도 다르면 실패다.
static int compare_bins(const unsigned int* ref, const unsigned int* got) {
    for (int b = 0; b < NUM_BINS; ++b) {
        if (ref[b] != got[b]) {
            printf("  bin %d: 기대 %u 실제 %u\n", b, ref[b], got[b]);
            return 0;
        }
    }
    return 1;
}

static unsigned long long sum_bins(const unsigned int* bins) {
    unsigned long long sum = 0;
    for (int b = 0; b < NUM_BINS; ++b) sum += bins[b];
    return sum;
}

static void launch(int which, unsigned int grid,
                   unsigned char* image_d, unsigned int* bins_d,
                   unsigned int width, unsigned int height) {
    switch (which) {
        case 0: histogram_race_kernel   <<<grid, BLOCK_DIM>>>(image_d, bins_d, width, height); break;
        case 1: histogram_atomic_kernel <<<grid, BLOCK_DIM>>>(image_d, bins_d, width, height); break;
        case 2: histogram_private_kernel<<<grid, BLOCK_DIM>>>(image_d, bins_d, width, height); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

int main(int argc, char** argv) {

    size_t N      = 1u << 26;
    int    skewed = 0;

    for (int a = 1; a < argc; ++a) {
        if (strcmp(argv[a], "--skewed") == 0) skewed = 1;
        else                                  N = (size_t)strtoull(argv[a], NULL, 0);
    }
    if (N == 0) {
        fprintf(stderr, "N은 1 이상이어야 한다\n");
        return 1;
    }

    // 커널은 슬라이드 그대로 width*height 로 원소 수를 센다.
    // 이 실습은 1차원 배열을 다루므로 height를 1로 두고 width에 N을 넣는다.
    unsigned int width  = (unsigned int)N;
    unsigned int height = 1;
    if ((size_t)width != N) {
        fprintf(stderr, "N은 %u 이하여야 한다\n", 0xFFFFFFFFu);
        return 1;
    }

    printf("N = %zu, 분포 = %s\n", N, skewed ? "치우침" : "균등");

    unsigned char* image = (unsigned char*)malloc(N);
    init_image(image, N, 1u, skewed);

    unsigned int bins_ref[NUM_BINS];
    histogram_cpu(image, N, bins_ref);

    unsigned char* image_d;
    unsigned int*  bins_d;
    CUDA_CHECK(cudaMalloc((void**) &image_d, N));
    CUDA_CHECK(cudaMalloc((void**) &bins_d, NUM_BINS*sizeof(unsigned int)));
    CUDA_CHECK(cudaMemcpy(image_d, image, N, cudaMemcpyHostToDevice));

    unsigned int grid = (unsigned int)((N + BLOCK_DIM - 1)/BLOCK_DIM);
    Timer timer;

    unsigned int bins[NUM_KERNELS][NUM_BINS];
    float times[NUM_KERNELS];

    for (int k = 0; k < NUM_KERNELS; ++k) {
        // 예열 — 첫 실행에는 초기화 비용이 섞인다
        CUDA_CHECK(cudaMemset(bins_d, 0, NUM_BINS*sizeof(unsigned int)));
        launch(k, grid, image_d, bins_d, width, height);
        CUDA_CHECK(cudaDeviceSynchronize());

        // 측정 — bins 초기화는 시간에 넣지 않는다
        CUDA_CHECK(cudaMemset(bins_d, 0, NUM_BINS*sizeof(unsigned int)));
        CUDA_CHECK(cudaDeviceSynchronize());
        timer.start();
        launch(k, grid, image_d, bins_d, width, height);
        times[k] = timer.stop();

        CUDA_CHECK(cudaMemcpy(bins[k], bins_d, NUM_BINS*sizeof(unsigned int),
                              cudaMemcpyDeviceToHost));
    }

    int ok_private = 0;
    for (int k = 0; k < NUM_KERNELS; ++k) {
        unsigned long long sum = sum_bins(bins[k]);

        // TODO를 안 채우면 bins에 아무것도 쌓이지 않아 합계가 0이 된다.
        if (sum == 0) {
            printf("%-7s : (미구현)\n", KERNEL_NAMES[k]);
            continue;
        }

        int ok = compare_bins(bins_ref, bins[k]);
        if (k == 2) ok_private = ok;

        if (sum == (unsigned long long)N) {
            printf("%-7s : %7.2f ms   합계 %llu%*s   %s\n",
                   KERNEL_NAMES[k], times[k], sum, 18, "", ok ? "PASS" : "FAIL");
        } else {
            printf("%-7s : %7.2f ms   합계 %llu   (기대 %zu)   %s\n",
                   KERNEL_NAMES[k], times[k], sum, N, ok ? "PASS" : "FAIL");
        }
    }

    free(image);
    CUDA_CHECK(cudaFree(image_d));
    CUDA_CHECK(cudaFree(bins_d));
    return ok_private ? 0 : 1;
}
