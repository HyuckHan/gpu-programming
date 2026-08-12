// 4주차 — 워프 분기 측정
// 아래 두 커널은 조건문 한 줄만 다르고 나머지는 완전히 같다.
// 직접 열어서 어느 줄이 다른지 확인하는 것이 이 실습의 핵심이다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"

// ---------------------------------------------------------------------------
// 같은 워프 안에서 갈라지는 버전
// ---------------------------------------------------------------------------
__global__ void divergent_kernel(float* out, int N, int iters) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;
    if (i < N) {
        float v = out[i];
        if (i % 2 == 0) {
            for (int k = 0; k < iters; ++k) v = v*1.0001f + 0.5f;
        } else {
            for (int k = 0; k < iters; ++k) v = v*0.9999f + 0.5f;
        }
        out[i] = v;
    }
}

// ---------------------------------------------------------------------------
// 워프 단위로 갈라지는 버전
// ---------------------------------------------------------------------------
__global__ void uniform_kernel(float* out, int N, int iters) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;
    if (i < N) {
        float v = out[i];
        if ((i / 32) % 2 == 0) {
            for (int k = 0; k < iters; ++k) v = v*1.0001f + 0.5f;
        } else {
            for (int k = 0; k < iters; ++k) v = v*0.9999f + 0.5f;
        }
        out[i] = v;
    }
}

// ---------------------------------------------------------------------------
// 호스트 코드
// ---------------------------------------------------------------------------

// 커널을 부르는 곳은 여기 두 함수뿐이다.
// 커널 이름이 아래쪽 코드에 흩어져 있으면 diff 로 두 커널만 비교할 때
// 호출부가 섞여 들어간다. 그래서 한곳에 모아 두었다.
static void launch_divergent(int grid, int block, float* out_d, int N, int iters) {
    divergent_kernel<<<grid, block>>>(out_d, N, iters);
}

static void launch_uniform(int grid, int block, float* out_d, int N, int iters) {
    uniform_kernel<<<grid, block>>>(out_d, N, iters);
}

// 입력을 [0, 1) 균등난수로 채운다. 시드가 같으면 항상 같은 값이 나온다.
static void init_data(float* out, int N, unsigned int seed) {
    unsigned int s = seed;
    for (int i = 0; i < N; ++i) {
        s = s*1664525u + 1013904223u;                 // 선형 합동 생성기
        out[i] = (float)(s >> 8)/16777216.0f;
    }
}

// 커널이 실제로 무언가 계산했는지 확인하는 용도다. 두 값이 서로 다른 것은 정상이다.
static double sum_of(const float* out, int N) {
    double sum = 0.0;
    for (int i = 0; i < N; ++i) sum += out[i];
    return sum;
}

int main(int argc, char** argv) {

    int N        = (argc > 1) ? atoi(argv[1]) : 4194304;
    int iters    = (argc > 2) ? atoi(argv[2]) : 2000;
    int blockDim_= (argc > 3) ? atoi(argv[3]) : 256;

    if (N <= 0 || iters <= 0) {
        fprintf(stderr, "N과 iters는 1 이상이어야 한다 (받은 값: %d, %d)\n", N, iters);
        return 1;
    }
    // (i / 32)는 워프 크기 32를 가정한 식이다. blockDim이 32의 배수가 아니면
    // 블록 경계와 워프 경계가 어긋나 두 커널의 비교가 성립하지 않는다.
    if (blockDim_ < 32 || blockDim_ > 1024 || blockDim_ % 32 != 0) {
        fprintf(stderr, "blockDim은 32 이상 1024 이하의 32의 배수여야 한다 (받은 값: %d)\n",
                blockDim_);
        return 1;
    }

    size_t bytes = (size_t)N*sizeof(float);
    printf("N = %d, iters = %d, blockDim = %d\n\n", N, iters, blockDim_);

    float* out = (float*)malloc(bytes);
    init_data(out, N, 1u);

    // 두 커널이 같은 초기 데이터에서 시작하도록 원본을 따로 보관한다.
    float *out_orig_d, *out_d;
    CUDA_CHECK(cudaMalloc((void**) &out_orig_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &out_d, bytes));
    CUDA_CHECK(cudaMemcpy(out_orig_d, out, bytes, cudaMemcpyHostToDevice));

    int grid = (N + blockDim_ - 1)/blockDim_;
    Timer timer;
    float ms_div = 0.0f, ms_uni = 0.0f;
    double sum_div = 0.0, sum_uni = 0.0;

    // 분기 있음 — 예열 뒤 측정한다. 되돌리는 시간은 재지 않는다.
    CUDA_CHECK(cudaMemcpy(out_d, out_orig_d, bytes, cudaMemcpyDeviceToDevice));
    launch_divergent(grid, blockDim_, out_d, N, iters);
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(out_d, out_orig_d, bytes, cudaMemcpyDeviceToDevice));
    timer.start();
    launch_divergent(grid, blockDim_, out_d, N, iters);
    ms_div = timer.stop();
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaMemcpy(out, out_d, bytes, cudaMemcpyDeviceToHost));
    sum_div = sum_of(out, N);

    // 분기 없음
    CUDA_CHECK(cudaMemcpy(out_d, out_orig_d, bytes, cudaMemcpyDeviceToDevice));
    launch_uniform(grid, blockDim_, out_d, N, iters);
    CUDA_CHECK(cudaDeviceSynchronize());
    CUDA_CHECK(cudaMemcpy(out_d, out_orig_d, bytes, cudaMemcpyDeviceToDevice));
    timer.start();
    launch_uniform(grid, blockDim_, out_d, N, iters);
    ms_uni = timer.stop();
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaMemcpy(out, out_d, bytes, cudaMemcpyDeviceToHost));
    sum_uni = sum_of(out, N);

    printf("분기 있음 (i %% 2)      : %8.2f ms\n", ms_div);
    printf("분기 없음 ((i/32) %% 2) : %8.2f ms\n", ms_uni);
    printf("비율                   : %8.2f 배\n", ms_div/ms_uni);
    printf("\n결과 합 (분기 있음 / 분기 없음) : %.6e / %.6e\n", sum_div, sum_uni);

    free(out);
    CUDA_CHECK(cudaFree(out_orig_d));
    CUDA_CHECK(cudaFree(out_d));
    return 0;
}
