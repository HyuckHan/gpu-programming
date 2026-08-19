// lab07 — coalescing과 thread coarsening
// 채울 곳은 mm_tiled_coarse_kernel 본체 하나뿐이다. 나머지는 완성된 코드다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"
// 커널마다 예열 한 번 뒤 MEASURE_RUNS 번 재고 그중 가장 빠른 값을 쓴다.
//
// N=4096 행렬곱을 연달아 돌리면 GPU 가 전력·온도 한계에 걸려 클럭이 내려간다.
// 실제로 같은 정상 커널이 1160 GFLOP/s 에서 530 대로 절반 떨어졌다가 한참 뒤에
// 회복하는 구간이 관찰됐다. 그 구간에서 잰 값은 커널의 성능이 아니라 그때의
// 온도다. 방해는 시간을 늘리기만 하므로, 여러 번 재서 가장 빠른 값을 고르면
// 방해받지 않은 실행을 고르는 셈이 된다. lab04 divergence.cu 와 같은 방식이다.
//
// 5회가 아니라 3회인 것은 4096 행렬곱 한 번이 100ms 를 넘기 때문이다.
#define MEASURE_RUNS 3


// ---------------------------------------------------------------------------
// naive 행렬곱 — lab05에서 직접 만든 커널 (완성)
// 오늘은 기준선으로만 쓴다.
// ---------------------------------------------------------------------------
__global__ void mm_kernel(float* A, float* B, float* C, unsigned int N) {

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int col = blockIdx.x*blockDim.x + threadIdx.x;

    float sum = 0.0f;
    for(unsigned int i = 0; i < N; ++i) {
        sum += A[row*N + i]*B[i*N + col];
    }
    C[row*N + col] = sum;

}

// ---------------------------------------------------------------------------
// 타일링 행렬곱 — lab06에서 직접 만든 커널 (완성)
// 오늘은 기준선으로만 쓴다.
// ---------------------------------------------------------------------------
template <unsigned int TILE_DIM>
__global__ void mm_tiled_kernel(float* A, float* B, float* C, unsigned int N) {

    __shared__ float A_s[TILE_DIM][TILE_DIM];
    __shared__ float B_s[TILE_DIM][TILE_DIM];

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int col = blockIdx.x*blockDim.x + threadIdx.x;

    float sum = 0.0f;

    for(unsigned int tile = 0; tile < N/TILE_DIM; ++tile) {

        // Load tile to shared memory
        A_s[threadIdx.y][threadIdx.x] = A[row*N + tile*TILE_DIM + threadIdx.x];
        B_s[threadIdx.y][threadIdx.x] = B[(tile*TILE_DIM + threadIdx.y)*N + col];
        __syncthreads();

        // Compute with tile
        for(unsigned int i = 0; i < TILE_DIM; ++i) {
            sum += A_s[threadIdx.y][i]*B_s[i][threadIdx.x];
        }
        __syncthreads();

    }

    C[row*N + col] = sum;

}

// ---------------------------------------------------------------------------
// 타일링 + thread coarsening — 여기를 채운다 (슬라이드 22)
//
// 슬라이드 22는 A가 M×N, B가 N×K인 직사각 표기라 매개변수가 M, N, K 세 개다.
// 이 실습은 lab05, lab06과 맞춰 정사각(N×N)으로 단순화했으므로 N 하나만 받는다.
// 슬라이드에서 M과 K가 쓰인 자리에 전부 N을 넣으면 된다. 이것이 슬라이드와
// 다른 유일한 지점이다.
//
// TILE_DIM은 shared memory 배열의 크기, COARSE_FACTOR는 sum 배열의 크기라서
// 둘 다 컴파일 시점에 정해져야 한다. 그래서 커널을 template로 두고 호스트에서
// 조합을 골라 부른다. 커널 안에서는 그냥 상수다.
// ---------------------------------------------------------------------------
template <unsigned int TILE_DIM, unsigned int COARSE_FACTOR>
__global__ void mm_tiled_coarse_kernel(float* A, float* B, float* C, unsigned int N) {

    __shared__ float A_s[TILE_DIM][TILE_DIM];
    __shared__ float B_s[TILE_DIM][TILE_DIM];

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int colStart = blockIdx.x*blockDim.x*COARSE_FACTOR + threadIdx.x;

    float sum[COARSE_FACTOR];
    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        sum[c] = 0.0f;
    }

    for(unsigned int tile = 0; tile < N/TILE_DIM; ++tile) {

        // Load A tile — c 루프 바깥에서 한 번만 읽는다. 이것이 coarsening 의 핵심이다.
        A_s[threadIdx.y][threadIdx.x] = A[row*N + tile*TILE_DIM + threadIdx.x];

        for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
            unsigned int col = colStart + c*TILE_DIM;

            // Load B tile
            B_s[threadIdx.y][threadIdx.x] = B[(tile*TILE_DIM + threadIdx.y)*N + col];
            __syncthreads();

            // Compute with tile
            for(unsigned int i = 0; i < TILE_DIM; ++i) {
                sum[c] += A_s[threadIdx.y][i]*B_s[i][threadIdx.x];
            }
            __syncthreads();

        }

    }

    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        unsigned int col = colStart + c*TILE_DIM;
        C[row*N + col] = sum[c];
    }

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

// N x N 행렬을 -0.5 ~ 0.5 난수로 채운다.
// 시드가 같으면 어느 PC에서 몇 번을 돌려도 같은 값이 나온다(재현 가능).
static void init_matrix(float* M, unsigned int N, unsigned int seed) {
    unsigned int s = seed;
    for (unsigned int i = 0; i < N*N; ++i) {
        s = s*1664525u + 1013904223u;                     // 선형 합동 생성기
        M[i] = (float)(s >> 16)/65536.0f - 0.5f;
    }
}

// CPU 참조 행렬곱. lab01 워밍업에서 직접 작성한 함수와 같은 것이다.
// O(N^3)이라 N이 커지면 매우 느리다. 작은 N에서만 쓴다.
static void mat_mul(const float* A, const float* B, float* C, int N) {
    for (int row = 0; row < N; ++row) {
        for (int col = 0; col < N; ++col) {
            float sum = 0.0f;
            for (int i = 0; i < N; ++i) {
                sum += A[row*N + i]*B[i*N + col];
            }
            C[row*N + col] = sum;
        }
    }
}

static void launch_tiled(unsigned int tile_dim, dim3 grid, dim3 block,
                         float* A_d, float* B_d, float* C_d, unsigned int N) {
    switch (tile_dim) {
        case  8: mm_tiled_kernel< 8><<<grid, block>>>(A_d, B_d, C_d, N); break;
        case 16: mm_tiled_kernel<16><<<grid, block>>>(A_d, B_d, C_d, N); break;
        case 32: mm_tiled_kernel<32><<<grid, block>>>(A_d, B_d, C_d, N); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

// TILE_DIM과 COARSE_FACTOR의 조합마다 커널이 하나씩 만들어진다.
// 12가지를 일일이 적는 대신 매크로로 줄였다. 고칠 일은 없는 코드다.
static void launch_coarse(unsigned int tile_dim, unsigned int coarse_factor,
                          dim3 grid, dim3 block,
                          float* A_d, float* B_d, float* C_d, unsigned int N) {
#define LAUNCH_COARSE(T, C) \
    mm_tiled_coarse_kernel<T, C><<<grid, block>>>(A_d, B_d, C_d, N)
#define COARSE_CASES(T)                                                   \
    switch (coarse_factor) {                                              \
        case 1: LAUNCH_COARSE(T, 1); break;                               \
        case 2: LAUNCH_COARSE(T, 2); break;                               \
        case 4: LAUNCH_COARSE(T, 4); break;                               \
        case 8: LAUNCH_COARSE(T, 8); break;                               \
        case 16: LAUNCH_COARSE(T, 16); break;                             \
        case 32: LAUNCH_COARSE(T, 32); break;                             \
    }
    switch (tile_dim) {
        case  8: COARSE_CASES( 8); break;
        case 16: COARSE_CASES(16); break;
        case 32: COARSE_CASES(32); break;
    }
#undef COARSE_CASES
#undef LAUNCH_COARSE
    CUDA_CHECK(cudaGetLastError());
}

// TODO를 안 채우면 커널이 C에 아무것도 쓰지 않아 전부 0으로 남는다.
// 그 경우만 (미구현)으로 본다.
static int all_zero(const float* C, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        if (C[i] != 0.0f) return 0;
    }
    return 1;
}

int main(int argc, char** argv) {

    unsigned int N             = (argc > 1) ? (unsigned int)atoi(argv[1]) : 4096;
    unsigned int TILE_DIM      = (argc > 2) ? (unsigned int)atoi(argv[2]) : 16;
    unsigned int COARSE_FACTOR = (argc > 3) ? (unsigned int)atoi(argv[3]) : 4;

    if (TILE_DIM != 8 && TILE_DIM != 16 && TILE_DIM != 32) {
        fprintf(stderr, "TILE_DIM은 8, 16, 32 중 하나여야 한다 (받은 값: %u)\n", TILE_DIM);
        return 1;
    }
    if (COARSE_FACTOR != 1 && COARSE_FACTOR != 2 && COARSE_FACTOR != 4 &&
        COARSE_FACTOR != 8 && COARSE_FACTOR != 16 && COARSE_FACTOR != 32) {
        fprintf(stderr, "COARSE_FACTOR는 1, 2, 4, 8, 16, 32 중 하나여야 한다 (받은 값: %u)\n",
                COARSE_FACTOR);
        return 1;
    }
    // 슬라이드 커널들에는 경계 검사가 없다.
    // coarsened 커널은 블록 하나가 가로로 TILE_DIM*COARSE_FACTOR 열을 담당한다.
    if (N == 0 || N % (TILE_DIM*COARSE_FACTOR) != 0) {
        fprintf(stderr, "N은 TILE_DIM*COARSE_FACTOR(=%u)의 배수여야 한다 (N=%u)\n",
                TILE_DIM*COARSE_FACTOR, N);
        return 1;
    }
    // 기준선 naive는 TILE_DIM과 무관하게 항상 16x16으로 돌린다.
    if (N % 16 != 0) {
        fprintf(stderr, "N은 16의 배수여야 한다 (기준선 naive가 16x16 고정이다, N=%u)\n", N);
        return 1;
    }
    if (N > 8192) {
        fprintf(stderr, "N은 8192 이하로 한다 (VRAM)\n");
        return 1;
    }

    size_t bytes = (size_t)N*N*sizeof(float);
    size_t count = (size_t)N*N;
    printf("N=%u, TILE_DIM=%u, COARSE_FACTOR=%u   행렬 하나당 %.1f MB\n",
           N, TILE_DIM, COARSE_FACTOR, bytes/(1024.0*1024.0));
    printf("커널마다 예열 1회 뒤 %d회 측정, 그중 가장 빠른 값을 쓴다.\n", MEASURE_RUNS);

    float* A        = (float*)malloc(bytes);
    float* B        = (float*)malloc(bytes);
    float* C_naive  = (float*)malloc(bytes);
    float* C_tiled  = (float*)malloc(bytes);
    float* C_coarse = (float*)malloc(bytes);
    init_matrix(A, N, 1u);
    init_matrix(B, N, 2u);

    float *A_d, *B_d, *C_d;
    CUDA_CHECK(cudaMalloc((void**) &A_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &B_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &C_d, bytes));
    CUDA_CHECK(cudaMemcpy(A_d, A, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(B_d, B, bytes, cudaMemcpyHostToDevice));

    Timer timer;

    // 기준선 naive — TILE_DIM을 바꿔도 항상 16x16이다.
    // 기준선이 같이 흔들리면 배속을 해석할 수 없다.
    dim3 block_naive(16, 16);
    dim3 grid_naive(N/16, N/16);
    mm_kernel<<<grid_naive, block_naive>>>(A_d, B_d, C_d, N);   // 예열
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    float ms_naive = 0.0f;
    for (int r_ = 0; r_ < MEASURE_RUNS; ++r_) {
        timer.start();
        mm_kernel<<<grid_naive, block_naive>>>(A_d, B_d, C_d, N);
        float ms_ = timer.stop();
        if (r_ == 0 || ms_ < ms_naive) ms_naive = ms_;
    }
    CUDA_CHECK(cudaMemcpy(C_naive, C_d, bytes, cudaMemcpyDeviceToHost));

    // tiled
    dim3 block_tiled(TILE_DIM, TILE_DIM);
    dim3 grid_tiled(N/TILE_DIM, N/TILE_DIM);
    launch_tiled(TILE_DIM, grid_tiled, block_tiled, A_d, B_d, C_d, N);   // 예열
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    float ms_tiled = 0.0f;
    for (int r_ = 0; r_ < MEASURE_RUNS; ++r_) {
        timer.start();
        launch_tiled(TILE_DIM, grid_tiled, block_tiled, A_d, B_d, C_d, N);
        float ms_ = timer.stop();
        if (r_ == 0 || ms_ < ms_tiled) ms_tiled = ms_;
    }
    CUDA_CHECK(cudaMemcpy(C_tiled, C_d, bytes, cudaMemcpyDeviceToHost));

    // tiled + coarsening
    // 블록 하나가 가로로 TILE_DIM*COARSE_FACTOR 열을 맡으므로 grid의 x를 그만큼 줄인다.
    dim3 block_coarse(TILE_DIM, TILE_DIM);
    dim3 grid_coarse(N/(TILE_DIM*COARSE_FACTOR), N/TILE_DIM);
    launch_coarse(TILE_DIM, COARSE_FACTOR, grid_coarse, block_coarse, A_d, B_d, C_d, N);   // 예열
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    // TODO 미채움을 알아보려면 측정 전에 C를 0으로 되돌려 두어야 한다.
    CUDA_CHECK(cudaMemset(C_d, 0, bytes));
    CUDA_CHECK(cudaDeviceSynchronize());
    float ms_coarse = 0.0f;
    for (int r_ = 0; r_ < MEASURE_RUNS; ++r_) {
        timer.start();
        launch_coarse(TILE_DIM, COARSE_FACTOR, grid_coarse, block_coarse, A_d, B_d, C_d, N);
        float ms_ = timer.stop();
        if (r_ == 0 || ms_ < ms_coarse) ms_coarse = ms_;
    }
    CUDA_CHECK(cudaMemcpy(C_coarse, C_d, bytes, cudaMemcpyDeviceToHost));

    int coarse_done = !all_zero(C_coarse, count);

    // 정확성 — tiled와 coarse를 naive와 대조한다.
    // 위치는 1차원 인덱스로 나온다. 행 = i/N, 열 = i%N 으로 읽으면 된다.
    int ok_tiled  = compare_float(C_naive, C_tiled, count, 1e-3f);
    int ok_coarse = coarse_done ? compare_float(C_naive, C_coarse, count, 1e-3f) : 0;

    // N이 작을 때만 CPU 참조까지 확인한다 (O(N^3)이라 크면 너무 느리다)
    if (ok_tiled && N <= 1024) {
        float* C_ref = (float*)malloc(bytes);
        mat_mul(A, B, C_ref, N);
        ok_tiled = compare_float(C_ref, C_tiled, count, 1e-3f);
        printf("CPU 참조 대조: %s\n", ok_tiled ? "일치" : "불일치");
        free(C_ref);
    }

    double gflop = 2.0*N*N*N/1e9;
    printf("naive        : %8.1f ms   %7.1f GFLOP/s   1.00x  (기준선, 16x16 고정)\n",
           ms_naive, gflop/(ms_naive/1e3));
    printf("tiled        : %8.1f ms   %7.1f GFLOP/s   %.2fx\n",
           ms_tiled, gflop/(ms_tiled/1e3), ms_naive/ms_tiled);
    if (coarse_done) {
        printf("tiled+coarse : %8.1f ms   %7.1f GFLOP/s   %.2fx\n",
               ms_coarse, gflop/(ms_coarse/1e3), ms_naive/ms_coarse);
    } else {
        printf("tiled+coarse : (미구현)\n");
    }
    printf("정확성: tiled=%s  coarse=%s\n",
           ok_tiled ? "PASS" : "FAIL",
           coarse_done ? (ok_coarse ? "PASS" : "FAIL") : "미구현");

    free(A); free(B); free(C_naive); free(C_tiled); free(C_coarse);
    CUDA_CHECK(cudaFree(A_d)); CUDA_CHECK(cudaFree(B_d)); CUDA_CHECK(cudaFree(C_d));
    return (ok_tiled && ok_coarse) ? 0 : 1;
}
