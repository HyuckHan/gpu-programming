// 12주차 — 리덕션 5단계 최적화 사다리
// 채울 곳은 reduce_shared_kernel 과 reduce_coarse_kernel 두 개뿐이다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"

#define BLOCK_DIM     256
#define COARSE_FACTOR 4

// ---------------------------------------------------------------------------
// 1단계 — 슬라이드 4: Parallel Reduction with Atomics (완성)
// ---------------------------------------------------------------------------
__global__ void reduce_atomic_kernel(float* input, float* sum, unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(i < N) {
        atomicAdd(sum, input[i]);
    }

}

// ---------------------------------------------------------------------------
// 2단계 — 슬라이드 9: Reduction Code (완성)
// 블록 하나가 2*BLOCK_DIM개를 맡는다. 결과는 input[segment]에 남는다.
// ---------------------------------------------------------------------------
__global__ void reduce_naive_kernel(float* input, float* sum, unsigned int N) {

    unsigned int segment = 2*blockDim.x*blockIdx.x;
    unsigned int i = segment + 2*threadIdx.x;
    for(unsigned int stride = 1; stride <= BLOCK_DIM; stride *= 2) {
        if(threadIdx.x%stride == 0) {
            input[i] += input[i + stride];
        }
        __syncthreads();
    }

    if(threadIdx.x == 0) {
        atomicAdd(sum, input[segment]);
    }

}

// ---------------------------------------------------------------------------
// 3단계 — 슬라이드 13: Coalescing and Minimizing Divergence (완성)
// ---------------------------------------------------------------------------
__global__ void reduce_coalesced_kernel(float* input, float* sum, unsigned int N) {

    unsigned int segment = 2*blockDim.x*blockIdx.x;
    unsigned int i = segment + threadIdx.x;
    for(unsigned int stride = BLOCK_DIM; stride > 0; stride /= 2) {
        if(threadIdx.x < stride) {
            input[i] += input[i + stride];
        }
        __syncthreads();
    }

    if(threadIdx.x == 0) {
        atomicAdd(sum, input[segment]);
    }

}

// ---------------------------------------------------------------------------
// 4단계 — 슬라이드 16: Reduction Code with Shared Memory  [필수 과제]
// ---------------------------------------------------------------------------
__global__ void reduce_shared_kernel(float* input, float* sum, unsigned int N) {

    __shared__ float input_s[BLOCK_DIM];

    // TODO를 채우기 전에도 결과가 0이 되도록 해 둔 것이다.
    // 그래야 프로그램이 미구현 상태를 알아보고 (미구현)으로 표시한다.
    // TODO를 채우면 이 값은 자연스럽게 덮어써진다.
    input_s[threadIdx.x] = 0.0f;
    __syncthreads();

    unsigned int segment = 2*blockDim.x*blockIdx.x;
    unsigned int i = segment + threadIdx.x;

    // Load data to shared memory
    input_s[threadIdx.x] = input[i] + input[i + BLOCK_DIM];
    __syncthreads();

    // Reduction tree in shared memory
    for(unsigned int stride = BLOCK_DIM/2; stride > 0; stride /= 2) {
        if(threadIdx.x < stride) {
            input_s[threadIdx.x] += input_s[threadIdx.x + stride];
        }
        __syncthreads();
    }

    if(threadIdx.x == 0) {
        atomicAdd(sum, input_s[0]);
    }

}

// ---------------------------------------------------------------------------
// 5단계 — 슬라이드 20: Reduction with Thread Coarsening  [도전 과제, 선택]
// 블록 하나가 COARSE_FACTOR*2*BLOCK_DIM개를 맡는다.
// ---------------------------------------------------------------------------
__global__ void reduce_coarse_kernel(float* input, float* sum, unsigned int N) {

    __shared__ float input_s[BLOCK_DIM];

    input_s[threadIdx.x] = 0.0f;
    __syncthreads();

    unsigned int segment = COARSE_FACTOR*2*blockDim.x*blockIdx.x;
    unsigned int i = segment + threadIdx.x;

    // Load data to shared memory
    float threadSum = 0.0f;
    for(unsigned int c = 0; c < COARSE_FACTOR*2; ++c) {
        threadSum += input[i + c*BLOCK_DIM];
    }
    input_s[threadIdx.x] = threadSum;
    __syncthreads();

    // Reduction tree in shared memory
    for(unsigned int stride = BLOCK_DIM/2; stride > 0; stride /= 2) {
        if(threadIdx.x < stride) {
            input_s[threadIdx.x] += input_s[threadIdx.x + stride];
        }
        __syncthreads();
    }

    if(threadIdx.x == 0) {
        atomicAdd(sum, input_s[0]);
    }

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

#define NUM_KERNELS 5
static const char* KERNEL_NAMES[NUM_KERNELS] = {
    "atomic", "naive", "coalesced", "shared", "coarsened"
};

// 입력을 [0, 1) 균등난수로 채운다. 시드가 같으면 항상 같은 값이 나온다.
static void init_input(float* input, unsigned int N, unsigned int seed) {
    unsigned int s = seed;
    for (unsigned int i = 0; i < N; ++i) {
        s = s*1664525u + 1013904223u;                 // 선형 합동 생성기
        input[i] = (float)(s >> 8)/16777216.0f;       // 상위 24비트를 2^24로 나눈다
    }
}

// 같은 배열을 float로 더한 것과 double로 더한 것. 순서는 둘 다 앞에서 뒤로 같다.
static float sum_cpu_float(const float* input, unsigned int N) {
    float sum = 0.0f;
    for (unsigned int i = 0; i < N; ++i) sum += input[i];
    return sum;
}

static double sum_cpu_double(const float* input, unsigned int N) {
    double sum = 0.0;
    for (unsigned int i = 0; i < N; ++i) sum += input[i];
    return sum;
}

// 커널마다 블록 하나가 맡는 원소 수가 다르다.
static unsigned int grid_of(int which, unsigned int N) {
    switch (which) {
        case 0: return N/BLOCK_DIM;                      // atomic: 스레드 하나가 원소 하나
        case 1:                                          // naive
        case 2:                                          // coalesced
        case 3: return N/(2*BLOCK_DIM);                  // shared
        case 4: return N/(COARSE_FACTOR*2*BLOCK_DIM);    // coarsened
    }
    return 0;
}

static void launch(int which, unsigned int grid, float* input_d, float* sum_d, unsigned int N) {
    switch (which) {
        case 0: reduce_atomic_kernel   <<<grid, BLOCK_DIM>>>(input_d, sum_d, N); break;
        case 1: reduce_naive_kernel    <<<grid, BLOCK_DIM>>>(input_d, sum_d, N); break;
        case 2: reduce_coalesced_kernel<<<grid, BLOCK_DIM>>>(input_d, sum_d, N); break;
        case 3: reduce_shared_kernel   <<<grid, BLOCK_DIM>>>(input_d, sum_d, N); break;
        case 4: reduce_coarse_kernel   <<<grid, BLOCK_DIM>>>(input_d, sum_d, N); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

int main(int argc, char** argv) {

    unsigned int N = (argc > 1) ? (unsigned int)strtoul(argv[1], NULL, 0) : (1u << 26);

    // 슬라이드 커널들에는 경계 검사가 없다. 항상 나누어떨어지게 유지해야 한다.
    if (N < 2048 || (N & (N - 1)) != 0) {
        fprintf(stderr, "N은 2의 거듭제곱이어야 하고 2048 이상이어야 한다 (받은 값: %u)\n", N);
        fprintf(stderr, "예:  ./reduce 67108864   또는   ./reduce 0x4000000\n");
        return 1;
    }
    if (N > (1u << 28)) {
        fprintf(stderr, "N은 2^28 이하로 한다 (VRAM)\n");
        return 1;
    }

    size_t bytes = (size_t)N*sizeof(float);
    printf("N = %u (%.1f MB), BLOCK_DIM = %d, COARSE_FACTOR = %d\n",
           N, bytes/(1024.0*1024.0), BLOCK_DIM, COARSE_FACTOR);

    float bw_peak = theoretical_bandwidth_GBps();
    if (bw_peak > 0.0f) printf("이론 대역폭 = %.1f GB/s\n", bw_peak);
    printf("\n");

    float* input = (float*)malloc(bytes);
    init_input(input, N, 1u);

    float  cpu_f = sum_cpu_float(input, N);
    double cpu_d = sum_cpu_double(input, N);
    printf("CPU (float,  순차): %.6f\n", cpu_f);
    printf("CPU (double, 순차): %.6f\n", cpu_d);

    // 원본을 디바이스에 따로 보관한다.
    // naive와 coalesced는 input을 제자리에서 뭉개므로, 커널마다 작업 버퍼를
    // 원본으로 되돌려 놓지 않으면 두 번째 커널부터 쓰레기값이 나온다.
    float *input_orig_d, *input_d, *sum_d;
    CUDA_CHECK(cudaMalloc((void**) &input_orig_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &input_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &sum_d, sizeof(float)));
    CUDA_CHECK(cudaMemcpy(input_orig_d, input, bytes, cudaMemcpyHostToDevice));

    float sums[NUM_KERNELS], times[NUM_KERNELS];
    int   ok[NUM_KERNELS];
    Timer timer;

    for (int k = 0; k < NUM_KERNELS; ++k) {
        unsigned int grid = grid_of(k, N);

        // 예열 — 첫 실행에는 초기화 비용이 섞인다
        CUDA_CHECK(cudaMemcpy(input_d, input_orig_d, bytes, cudaMemcpyDeviceToDevice));
        CUDA_CHECK(cudaMemset(sum_d, 0, sizeof(float)));
        launch(k, grid, input_d, sum_d, N);
        CUDA_CHECK(cudaDeviceSynchronize());

        // 측정 — 되돌리기와 초기화는 시간에 넣지 않는다
        CUDA_CHECK(cudaMemcpy(input_d, input_orig_d, bytes, cudaMemcpyDeviceToDevice));
        CUDA_CHECK(cudaMemset(sum_d, 0, sizeof(float)));
        CUDA_CHECK(cudaDeviceSynchronize());
        timer.start();
        launch(k, grid, input_d, sum_d, N);
        times[k] = timer.stop();

        CUDA_CHECK(cudaMemcpy(&sums[k], sum_d, sizeof(float), cudaMemcpyDeviceToHost));
        ok[k] = 0;
    }

    // TODO를 안 채운 커널은 합이 정확히 0으로 나온다. 그것만 (미구현)으로 본다.
    printf("\n=== 합계 ===\n");
    for (int k = 0; k < NUM_KERNELS; ++k) {
        if (sums[k] == 0.0f) {
            printf("%-10s : (미구현)\n", KERNEL_NAMES[k]);
            continue;
        }
        ok[k] = compare_scalar(sums[k], cpu_d, 1e-5);   // 어긋나면 상세를 먼저 찍는다
        printf("%-10s : %.6f   검증 %s\n",
               KERNEL_NAMES[k], sums[k], ok[k] ? "PASS" : "FAIL");
    }

    printf("\n=== 성능 ===\n");
    for (int k = 0; k < NUM_KERNELS; ++k) {
        if (sums[k] == 0.0f) {
            printf("%-10s : (미구현)\n", KERNEL_NAMES[k]);
            continue;
        }
        double gbps = (double)bytes/(times[k]/1.0e3)/1.0e9;   // 유효 대역폭 = N*4바이트 / 시간
        if (bw_peak > 0.0f) {
            printf("%-10s : %8.3f ms  %7.1f GB/s  (이론 대비 %5.1f%%)\n",
                   KERNEL_NAMES[k], times[k], gbps, 100.0*gbps/bw_peak);
        } else {
            printf("%-10s : %8.3f ms  %7.1f GB/s\n", KERNEL_NAMES[k], times[k], gbps);
        }
    }

    free(input);
    CUDA_CHECK(cudaFree(input_orig_d));
    CUDA_CHECK(cudaFree(input_d));
    CUDA_CHECK(cudaFree(sum_d));

    // 필수 과제는 shared 하나다. 그것만 통과하면 0으로 끝낸다.
    return (sums[3] != 0.0f && ok[3]) ? 0 : 1;
}
