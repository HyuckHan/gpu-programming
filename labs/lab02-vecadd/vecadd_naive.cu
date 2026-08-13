// 2주차 — 벡터 덧셈 (관찰용)
// 이 프로그램은 컴파일되고 실행도 된다. 결과를 관찰하는 것이 과제다.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.cuh"

// ---------------------------------------------------------------------------
// 슬라이드 18 — Parallel Vector Addition in CUDA
// ---------------------------------------------------------------------------
__global__ void vecadd_kernel(float* x, float* y, float* z, int N) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;
    z[i] = x[i] + y[i];
}

// ---------------------------------------------------------------------------
// 슬라이드 8 — 호스트 쪽 vecadd 골격
// 실행 구성은 슬라이드 12를 그대로 따른다.
// ---------------------------------------------------------------------------
static cudaError_t vecadd(float* x, float* y, float* z, int N,
                          unsigned int numThreadsPerBlock,
                          float* ms_h2d, float* ms_kernel, float* ms_d2h) {

    // Allocate GPU memory
    float *x_d, *y_d, *z_d;
    CUDA_CHECK(cudaMalloc((void**) &x_d, N*sizeof(float)));
    CUDA_CHECK(cudaMalloc((void**) &y_d, N*sizeof(float)));
    CUDA_CHECK(cudaMalloc((void**) &z_d, N*sizeof(float)));
    CUDA_CHECK(cudaMemset(z_d, 0, N*sizeof(float)));

    Timer timer;

    // Copy data to GPU memory
    timer.start();
    CUDA_CHECK(cudaMemcpy(x_d, x, N*sizeof(float), cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(y_d, y, N*sizeof(float), cudaMemcpyHostToDevice));
    *ms_h2d = timer.stop();

    // Perform computation on GPU
    const unsigned int numBlocks = N/numThreadsPerBlock;

    timer.start();
    vecadd_kernel <<< numBlocks, numThreadsPerBlock >>> (x_d, y_d, z_d, N);

    // 커널이 실패하더라도 여기서 멈추지 않는다. 결과까지 보여주고 정상 종료해야 한다.
    cudaError_t kernel_err = cudaDeviceSynchronize();
    *ms_kernel = (kernel_err == cudaSuccess) ? timer.stop() : 0.0f;
    if (kernel_err != cudaSuccess) return kernel_err;

    // Copy data from GPU memory
    timer.start();
    CUDA_CHECK(cudaMemcpy(z, z_d, N*sizeof(float), cudaMemcpyDeviceToHost));
    *ms_d2h = timer.stop();

    // Deallocate GPU memory
    CUDA_CHECK(cudaFree(x_d));
    CUDA_CHECK(cudaFree(y_d));
    CUDA_CHECK(cudaFree(z_d));
    return cudaSuccess;
}

// ---------------------------------------------------------------------------
// 호스트 코드
// ---------------------------------------------------------------------------

static void init_vector(float* v, int N, unsigned int seed) {
    unsigned int s = seed;
    for (int i = 0; i < N; ++i) {
        s = s*1664525u + 1013904223u;
        v[i] = (float)(s >> 8)/16777216.0f;
    }
}

static void vecadd_cpu(const float* x, const float* y, float* z, int N) {
    for (int i = 0; i < N; ++i) {
        z[i] = x[i] + y[i];
    }
}

static void print_occupancy(unsigned int numThreadsPerBlock) {
    int device = 0;
    cudaDeviceProp prop;
    int blocksPerSm = 0;
    if (cudaGetDevice(&device) != cudaSuccess ||
        cudaGetDeviceProperties(&prop, device) != cudaSuccess ||
        cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &blocksPerSm, vecadd_kernel, (int)numThreadsPerBlock, 0) != cudaSuccess) {
        cudaGetLastError();
        return;
    }
    int activeWarps = blocksPerSm*(int)numThreadsPerBlock/prop.warpSize;
    int maxWarps    = prop.maxThreadsPerMultiProcessor/prop.warpSize;
    printf("blockDim=%u  SM당 활성 블록 %d  activeWarps/maxWarps = %.1f%%\n",
           numThreadsPerBlock, blocksPerSm, 100.0*activeWarps/maxWarps);
}

int main(int argc, char** argv) {

    int          N                  = (argc > 1) ? atoi(argv[1]) : 9999999;
    unsigned int numThreadsPerBlock = (argc > 2) ? (unsigned int)atoi(argv[2]) : 256;

    if (N <= 0 || N > (1 << 28)) {
        fprintf(stderr, "N은 1 이상 %d 이하여야 한다 (받은 값: %d)\n", 1 << 28, N);
        return 1;
    }
    if (numThreadsPerBlock < 32 || numThreadsPerBlock > 1024 || numThreadsPerBlock % 32 != 0) {
        fprintf(stderr, "blockDim은 32 이상 1024 이하의 32의 배수여야 한다 (받은 값: %u)\n",
                numThreadsPerBlock);
        return 1;
    }

    size_t bytes = (size_t)N*sizeof(float);
    printf("N = %d, blockDim = %u, 배열 3개 합계 %.1f MB\n",
           N, numThreadsPerBlock, 3.0*bytes/(1024.0*1024.0));
    print_occupancy(numThreadsPerBlock);
    printf("\n");

    float* x     = (float*)malloc(bytes);
    float* y     = (float*)malloc(bytes);
    float* z     = (float*)malloc(bytes);
    float* z_ref = (float*)malloc(bytes);
    init_vector(x, N, 1u);
    init_vector(y, N, 2u);
    vecadd_cpu(x, y, z_ref, N);

    // 결과 버퍼를 미리 한 번 만져 둔다. 그러지 않으면 D2H 전송 시간에
    // 페이지 폴트 비용이 섞여 실행할 때마다 값이 출렁인다.
    memset(z, 0, bytes);
    CUDA_CHECK(cudaFree(0));

    float ms_h2d = 0.0f, ms_kernel = 0.0f, ms_d2h = 0.0f;
    cudaError_t kernel_err = vecadd(x, y, z, N, numThreadsPerBlock,
                                    &ms_h2d, &ms_kernel, &ms_d2h);

    if (kernel_err != cudaSuccess) {
        printf("커널이 끝까지 실행되지 못했다\n");
        printf("  %s\n", cudaGetErrorString(kernel_err));
        printf("검증: FAIL\n");
        free(x); free(y); free(z); free(z_ref);
        return 0;
    }

    int ok = compare_float(z_ref, z, (size_t)N, 1e-5f);
    printf("검증: %s\n\n", ok ? "PASS" : "FAIL");

    float total = ms_h2d + ms_kernel + ms_d2h;
    printf("H2D 전송 : %8.3f ms\n", ms_h2d);
    printf("커널     : %8.3f ms\n", ms_kernel);
    printf("D2H 전송 : %8.3f ms\n", ms_d2h);
    printf("─────────────────────────────────────\n");
    printf("전체     : %8.3f ms   (커널 비중 %.1f%%)\n", total, 100.0*ms_kernel/total);

    free(x); free(y); free(z); free(z_ref);
    return 0;
}
