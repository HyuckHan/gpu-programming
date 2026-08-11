// 6주차 — 타일링 행렬곱 (관찰용)
// 이 프로그램은 컴파일되고 실행도 된다. 결과를 관찰하는 것이 과제다.
#include <stdio.h>
#include <stdlib.h>
#include "../../common/common.cuh"

// ---------------------------------------------------------------------------
// naive 행렬곱 — 3주차에서 다룬 커널
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
// 타일링 행렬곱
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

        // Compute with tile
        for(unsigned int i = 0; i < TILE_DIM; ++i) {
            sum += A_s[threadIdx.y][i]*B_s[i][threadIdx.x];
        }
        __syncthreads();

    }

    C[row*N + col] = sum;

}

// ---------------------------------------------------------------------------
// 호스트 코드
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

static void launch_tiled(unsigned int tile_dim, dim3 grid, dim3 block,
                         float* A_d, float* B_d, float* C_d, unsigned int N) {
    switch (tile_dim) {
        case  8: mm_tiled_kernel< 8><<<grid, block>>>(A_d, B_d, C_d, N); break;
        case 16: mm_tiled_kernel<16><<<grid, block>>>(A_d, B_d, C_d, N); break;
        case 32: mm_tiled_kernel<32><<<grid, block>>>(A_d, B_d, C_d, N); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

int main(int argc, char** argv) {

    unsigned int N        = (argc > 1) ? (unsigned int)atoi(argv[1]) : 4096;
    unsigned int TILE_DIM = (argc > 2) ? (unsigned int)atoi(argv[2]) : 32;

    if (TILE_DIM != 8 && TILE_DIM != 16 && TILE_DIM != 32) {
        fprintf(stderr, "TILE_DIM은 8, 16, 32 중 하나여야 한다 (받은 값: %u)\n", TILE_DIM);
        return 1;
    }
    if (N == 0 || N % TILE_DIM != 0) {
        fprintf(stderr, "N은 TILE_DIM의 배수여야 한다 (N=%u, TILE_DIM=%u)\n", N, TILE_DIM);
        return 1;
    }
    if (N > 8192) {
        fprintf(stderr, "N은 8192 이하로 한다 (VRAM 8GB)\n");
        return 1;
    }

    size_t bytes = (size_t)N*N*sizeof(float);
    printf("N = %u, TILE_DIM = %u, 행렬 하나당 %.1f MB\n",
           N, TILE_DIM, bytes/(1024.0*1024.0));

    float* A       = (float*)malloc(bytes);
    float* B       = (float*)malloc(bytes);
    float* C_naive = (float*)malloc(bytes);
    float* C_tiled = (float*)malloc(bytes);
    init_matrix(A, N, 1u);
    init_matrix(B, N, 2u);

    float *A_d, *B_d, *C_d;
    CUDA_CHECK(cudaMalloc((void**) &A_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &B_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &C_d, bytes));
    CUDA_CHECK(cudaMemcpy(A_d, A, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(B_d, B, bytes, cudaMemcpyHostToDevice));

    dim3 block(TILE_DIM, TILE_DIM);
    dim3 grid(N/TILE_DIM, N/TILE_DIM);
    Timer timer;

    mm_kernel<<<grid, block>>>(A_d, B_d, C_d, N);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    timer.start();
    mm_kernel<<<grid, block>>>(A_d, B_d, C_d, N);
    float ms_naive = timer.stop();
    CUDA_CHECK(cudaMemcpy(C_naive, C_d, bytes, cudaMemcpyDeviceToHost));

    CUDA_CHECK(cudaMemset(C_d, 0, bytes));
    launch_tiled(TILE_DIM, grid, block, A_d, B_d, C_d, N);
    CUDA_CHECK(cudaDeviceSynchronize());
    timer.start();
    launch_tiled(TILE_DIM, grid, block, A_d, B_d, C_d, N);
    float ms_tiled = timer.stop();
    CUDA_CHECK(cudaMemcpy(C_tiled, C_d, bytes, cudaMemcpyDeviceToHost));

    int ok = compare_float(C_naive, C_tiled, (size_t)N*N, 1e-3f);

    double gflop = 2.0*N*N*N/1e9;
    printf("naive: %8.3f ms  (%7.1f GFLOP/s)\n", ms_naive, gflop/(ms_naive/1e3));
    printf("tiled: %8.3f ms  (%7.1f GFLOP/s)\n", ms_tiled, gflop/(ms_tiled/1e3));
    printf("정확성: %s\n", ok ? "PASS" : "FAIL");
    printf("배속: %.2fx\n", ms_naive/ms_tiled);

    free(A); free(B); free(C_naive); free(C_tiled);
    CUDA_CHECK(cudaFree(A_d)); CUDA_CHECK(cudaFree(B_d)); CUDA_CHECK(cudaFree(C_d));
    return ok ? 0 : 1;
}
