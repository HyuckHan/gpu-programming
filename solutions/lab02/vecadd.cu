// 2주차 — 벡터 덧셈
// 채울 곳은 // TODO: 두 군데뿐이다. 나머지는 완성된 코드다.
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "common.cuh"

// ---------------------------------------------------------------------------
// 슬라이드 21 — Code with Boundary Checks
// ---------------------------------------------------------------------------
__global__ void vecadd_kernel(float* x, float* y, float* z, int N) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;

    if(i < N) {
        z[i] = x[i] + y[i];
    }

}

// ---------------------------------------------------------------------------
// 슬라이드 8 — 호스트 쪽 vecadd 골격 (완성)
// 세 구간의 시간을 따로 재서 돌려준다.
// ---------------------------------------------------------------------------
static void vecadd(float* x, float* y, float* z, int N,
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
    //
    // 올림 나눗셈. N이 numThreadsPerBlock의 배수가 아니어도 뒤쪽 원소가 빠지지 않는다.
    const unsigned int numBlocks = (N + numThreadsPerBlock - 1)/numThreadsPerBlock;

    timer.start();
    vecadd_kernel <<< numBlocks, numThreadsPerBlock >>> (x_d, y_d, z_d, N);
    *ms_kernel = timer.stop();
    CUDA_CHECK(cudaGetLastError());

    // Copy data from GPU memory
    timer.start();
    CUDA_CHECK(cudaMemcpy(z, z_d, N*sizeof(float), cudaMemcpyDeviceToHost));
    *ms_d2h = timer.stop();

    // Deallocate GPU memory
    CUDA_CHECK(cudaFree(x_d));
    CUDA_CHECK(cudaFree(y_d));
    CUDA_CHECK(cudaFree(z_d));
}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

// 배열을 [0, 1) 균등난수로 채운다. 시드가 같으면 항상 같은 값이 나온다.
static void init_vector(float* v, int N, unsigned int seed) {
    unsigned int s = seed;
    for (int i = 0; i < N; ++i) {
        s = s*1664525u + 1013904223u;              // 선형 합동 생성기
        v[i] = (float)(s >> 8)/16777216.0f;
    }
}

// CPU 참조 구현. 커널이 내야 할 정답을 만든다.
static void vecadd_cpu(const float* x, const float* y, float* z, int N) {
    for (int i = 0; i < N; ++i) {
        z[i] = x[i] + y[i];
    }
}

// 지금 blockDim에서 SM 하나가 몇 블록을 동시에 올릴 수 있는지 조회해서 찍는다.
// 수치를 하드코딩하지 않는다. 실행 중인 GPU에 직접 물어본다.
static void print_occupancy(unsigned int numThreadsPerBlock) {
    int device = 0;
    cudaDeviceProp prop;
    int blocksPerSm = 0;
    if (cudaGetDevice(&device) != cudaSuccess ||
        cudaGetDeviceProperties(&prop, device) != cudaSuccess ||
        cudaOccupancyMaxActiveBlocksPerMultiprocessor(
            &blocksPerSm, vecadd_kernel, (int)numThreadsPerBlock, 0) != cudaSuccess) {
        cudaGetLastError();                        // 오류 상태를 남기지 않는다
        return;
    }
    int activeWarps = blocksPerSm*(int)numThreadsPerBlock/prop.warpSize;
    int maxWarps    = prop.maxThreadsPerMultiProcessor/prop.warpSize;
    printf("blockDim=%u  SM당 활성 블록 %d  activeWarps/maxWarps = %.1f%%\n",
           numThreadsPerBlock, blocksPerSm, 100.0*activeWarps/maxWarps);
}

// --info 로 부르면 이 GPU의 하드웨어 한계만 찍고 끝낸다.
// 4주차 실습에서 이 값들을 받아적어 occupancy를 손으로 계산한다.
// 수치를 하드코딩하지 않는다. 실행 중인 GPU에 직접 물어본다.
static void print_device_info(void) {
    int device = 0;
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDevice(&device));
    CUDA_CHECK(cudaGetDeviceProperties(&prop, device));

    printf("GPU                   : %s (compute capability %d.%d)\n",
           prop.name, prop.major, prop.minor);
    printf("SM 개수                : %d\n", prop.multiProcessorCount);
    printf("워프 크기              : %d\n", prop.warpSize);
    printf("SM당 최대 스레드 수    : %d\n", prop.maxThreadsPerMultiProcessor);
    printf("SM당 최대 블록 수      : %d\n", prop.maxBlocksPerMultiProcessor);
    printf("SM당 최대 워프 수      : %d\n", prop.maxThreadsPerMultiProcessor/prop.warpSize);
    printf("블록당 최대 스레드 수  : %d\n", prop.maxThreadsPerBlock);
}

int main(int argc, char** argv) {

    if (argc > 1 && strcmp(argv[1], "--info") == 0) {
        print_device_info();
        return 0;
    }

    int          N                   = (argc > 1) ? atoi(argv[1]) : 9999999;
    unsigned int numThreadsPerBlock  = (argc > 2) ? (unsigned int)atoi(argv[2]) : 256;

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

    // 결과 버퍼를 미리 한 번 만져 둔다. 그러지 않으면 호스트 페이지가 아직
    // 잡혀 있지 않아, D2H 전송 시간에 페이지 폴트 비용이 섞여 서너 배로 부풀고
    // 실행할 때마다 값이 출렁인다.
    memset(z, 0, bytes);

    // 첫 CUDA 호출에는 컨텍스트 초기화 비용이 섞인다. 측정 전에 미리 끝내 둔다.
    CUDA_CHECK(cudaFree(0));

    float ms_h2d = 0.0f, ms_kernel = 0.0f, ms_d2h = 0.0f;
    vecadd(x, y, z, N, numThreadsPerBlock, &ms_h2d, &ms_kernel, &ms_d2h);

    int ok = compare_float(z_ref, z, (size_t)N, 1e-5f);
    printf("검증: %s\n\n", ok ? "PASS" : "FAIL");

    float total = ms_h2d + ms_kernel + ms_d2h;
    printf("H2D 전송 : %8.3f ms\n", ms_h2d);
    printf("커널     : %8.3f ms\n", ms_kernel);
    printf("D2H 전송 : %8.3f ms\n", ms_d2h);
    printf("─────────────────────────────────────\n");
    printf("전체     : %8.3f ms   (커널 비중 %.1f%%)\n", total, 100.0*ms_kernel/total);

    free(x); free(y); free(z); free(z_ref);
    return ok ? 0 : 1;
}
