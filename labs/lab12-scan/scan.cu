// lab12 — 스캔 (Kogge-Stone)
// 채울 곳은 scan_global_kernel, scan_shared_kernel, scan_exclusive_kernel 세 군데다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"

#define BLOCK_DIM 1024

// ---------------------------------------------------------------------------
// 슬라이드 8 — Kogge-Stone (완성)
// ---------------------------------------------------------------------------
__global__ void scan_race_kernel(float* input, float* output, float* partialSums,
                                 unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    output[i] = input[i];

    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        if(threadIdx.x >= stride) {
            output[i] += output[i - stride];
        }
        __syncthreads();
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = output[i];
    }

}

// ---------------------------------------------------------------------------
// 슬라이드 10 — 여기를 채운다
//
// 위 커널과 같은 알고리즘인데 루프 본문만 다르다.
// float v 를 두어 읽는 시점과 쓰는 시점을 갈라 놓는 것이 요점이다.
// ---------------------------------------------------------------------------
__global__ void scan_global_kernel(float* input, float* output, float* partialSums,
                                   unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    output[i] = input[i];

    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {

        // TODO: 슬라이드 10의 루프 본문을 옮긴다.
        //   float v 를 선언하고
        //   threadIdx.x >= stride 인 스레드가 output[i - stride] 를 v 에 읽어 둔다
        //   블록 전체가 읽기를 끝낼 때까지 기다린다
        //   threadIdx.x >= stride 인 스레드가 output[i] 에 v 를 더한다
        //   블록 전체가 쓰기를 끝낼 때까지 기다린다

    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = output[i];
    }

}

// ---------------------------------------------------------------------------
// 슬라이드 13 — 여기를 채운다
//
// 같은 알고리즘을 공유 메모리에서 돌린다.
// 적재와 저장은 이미 되어 있다. 루프 본문만 채우면 된다.
// ---------------------------------------------------------------------------
__global__ void scan_shared_kernel(float* input, float* output, float* partialSums,
                                   unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    __shared__ float buffer_s[BLOCK_DIM];
    buffer_s[threadIdx.x] = input[i];
    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {

        // TODO: 슬라이드 13의 루프 본문을 옮긴다.
        //   구조는 슬라이드 10과 같다. output[i] 대신 buffer_s[threadIdx.x] 를,
        //   output[i - stride] 대신 buffer_s[threadIdx.x - stride] 를 쓴다.

    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = buffer_s[threadIdx.x];
    }

    output[i] = buffer_s[threadIdx.x];

}

// ---------------------------------------------------------------------------
// 슬라이드 15 — Double buffering (완성)
// 비교 대상으로만 쓴다. 루프 한 번에 __syncthreads() 를 몇 번 부르는지 세어 보라.
// ---------------------------------------------------------------------------
__global__ void scan_double_kernel(float* input, float* output, float* partialSums,
                                   unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    __shared__ float buffer1_s[BLOCK_DIM];
    __shared__ float buffer2_s[BLOCK_DIM];
    float* inBuffer_s = buffer1_s;
    float* outBuffer_s = buffer2_s;
    inBuffer_s[threadIdx.x] = input[i];
    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        if(threadIdx.x >= stride) {
            outBuffer_s[threadIdx.x] =
                    inBuffer_s[threadIdx.x] + inBuffer_s[threadIdx.x - stride];
        } else {
            outBuffer_s[threadIdx.x] = inBuffer_s[threadIdx.x];
        }
        __syncthreads();
        float* tmp = inBuffer_s;
        inBuffer_s = outBuffer_s;
        outBuffer_s = tmp;
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = inBuffer_s[threadIdx.x];
    }

    output[i] = inBuffer_s[threadIdx.x];

}

// ---------------------------------------------------------------------------
// 슬라이드 17 — Exclusive scan. 여기를 채운다 (도전 과제)
//
// 루프와 마무리는 슬라이드 15와 완전히 같다. 다른 곳은 처음 적재뿐이다.
// inclusive 는 자기 값까지 더하고, exclusive 는 자기 앞까지만 더한다.
// 그 차이를 적재 단계에서 만들어 낸다.
// ---------------------------------------------------------------------------
__global__ void scan_exclusive_kernel(float* input, float* output, float* partialSums,
                                      unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    __shared__ float buffer1_s[BLOCK_DIM];
    __shared__ float buffer2_s[BLOCK_DIM];
    float* inBuffer_s = buffer1_s;
    float* outBuffer_s = buffer2_s;

    // 채우기 전에도 결과가 0으로 나오게 해 둔 것이다.
    // 그래야 프로그램이 미구현 상태를 알아보고 (미구현)으로 표시한다.
    inBuffer_s[threadIdx.x] = 0.0f;

    // TODO: 슬라이드 17의 적재 부분으로 위 한 줄을 바꾼다.
    //   threadIdx.x 가 0 이면 0.0f 를 넣고,
    //   아니면 자기 바로 앞 원소인 input[i - 1] 을 넣는다.

    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        if(threadIdx.x >= stride) {
            outBuffer_s[threadIdx.x] =
                    inBuffer_s[threadIdx.x] + inBuffer_s[threadIdx.x - stride];
        } else {
            outBuffer_s[threadIdx.x] = inBuffer_s[threadIdx.x];
        }
        __syncthreads();
        float* tmp = inBuffer_s;
        inBuffer_s = outBuffer_s;
        outBuffer_s = tmp;
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = inBuffer_s[threadIdx.x] + input[i];
    }

    output[i] = inBuffer_s[threadIdx.x];

}

// ---------------------------------------------------------------------------
// 다중 블록 조립 (완성)
//
// 위 커널들은 블록 안에서만 스캔한다. 각 블록은 자기 구간의 합을
// partialSums[blockIdx.x] 에 남긴다. 전체 배열을 스캔하려면 세 단계가 필요하다.
//
//   1단계  블록별 스캔          위 커널들
//   2단계  partialSums 스캔     아래 scan_partials_kernel
//   3단계  앞선 블록들의 합 더하기  아래 add_offsets_kernel
//
// 이 조립은 슬라이드에 없다. 그래서 완성 상태로 제공한다.
// 2단계를 블록 하나로 끝내려고 N <= BLOCK_DIM*BLOCK_DIM 으로 제한한다.
// ---------------------------------------------------------------------------
__global__ void scan_partials_kernel(float* partialSums, unsigned int numBlocks) {

    __shared__ float buffer_s[BLOCK_DIM];
    unsigned int t = threadIdx.x;

    buffer_s[t] = (t < numBlocks) ? partialSums[t] : 0.0f;
    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        float v;
        if(t >= stride) {
            v = buffer_s[t - stride];
        }
        __syncthreads();
        if(t >= stride) {
            buffer_s[t] += v;
        }
        __syncthreads();
    }

    if(t < numBlocks) {
        partialSums[t] = buffer_s[t];
    }

}

__global__ void add_offsets_kernel(float* output, const float* partialSums,
                                   unsigned int N) {

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
    if(blockIdx.x > 0 && i < N) {
        output[i] += partialSums[blockIdx.x - 1];
    }

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

#define NUM_KERNELS 5
#define REPEATS     100
static const char* KERNEL_NAMES[NUM_KERNELS] = {
    "race", "global", "shared", "double", "exclusive"
};

// 입력을 [0, 1) 균등난수로 채운다. 시드가 같으면 항상 같은 값이 나온다.
// 스캔은 뒤로 갈수록 값이 커지므로 작은 값을 쓰는 것이 의도적이다.
static void init_input(float* input, unsigned int N, unsigned int seed) {
    unsigned int s = seed;
    for (unsigned int i = 0; i < N; ++i) {
        s = s*1664525u + 1013904223u;                 // 선형 합동 생성기
        input[i] = (float)(s >> 8)/16777216.0f;
    }
}

// CPU 참조. double 로 누적한다. float 로 누적하면 뒤로 갈수록 스스로 어긋나서
// 참조 구실을 못 한다 (리덕션 랩에서 확인한 것과 같은 이유다).
static void scan_cpu_inclusive(const float* input, float* output, unsigned int N) {
    double sum = 0.0;
    for (unsigned int i = 0; i < N; ++i) {
        sum += input[i];
        output[i] = (float)sum;
    }
}

static void scan_cpu_exclusive(const float* input, float* output, unsigned int N) {
    double sum = 0.0;
    for (unsigned int i = 0; i < N; ++i) {
        output[i] = (float)sum;
        sum += input[i];
    }
}

// 첫 불일치 위치를 찾는다. 판정 기준은 compare_float과 같다.
// 배열 전체의 대표 크기(RMS)로 오차를 나눈다.
static long long first_mismatch(const float* ref, const float* got,
                                unsigned int N, float tol) {
    double sq = 0.0;
    for (unsigned int i = 0; i < N; ++i) sq += (double)ref[i]*ref[i];
    float scale = (float)sqrt(sq/(double)N);
    if (scale < 1e-6f) scale = 1e-6f;

    for (unsigned int i = 0; i < N; ++i) {
        if (fabsf(ref[i] - got[i])/scale > tol || isnan(got[i])) return (long long)i;
    }
    return -1;
}

// TODO를 안 채운 커널은 스캔을 하지 않는다. 결과가 통째로 0이거나
// 입력을 그대로 옮겨 놓은 상태로 남는다. 그 두 경우만 (미구현)으로 본다.
static int looks_unimplemented(const float* input, const float* got, unsigned int N) {
    int all_zero = 1, same_as_input = 1;
    for (unsigned int i = 0; i < N; ++i) {
        if (got[i] != 0.0f)     all_zero = 0;
        if (got[i] != input[i]) same_as_input = 0;
        if (!all_zero && !same_as_input) return 0;
    }
    return 1;
}

static void launch_stage1(int which, unsigned int grid,
                          float* input_d, float* output_d, float* partialSums_d,
                          unsigned int N) {
    switch (which) {
        case 0: scan_race_kernel     <<<grid, BLOCK_DIM>>>(input_d, output_d, partialSums_d, N); break;
        case 1: scan_global_kernel   <<<grid, BLOCK_DIM>>>(input_d, output_d, partialSums_d, N); break;
        case 2: scan_shared_kernel   <<<grid, BLOCK_DIM>>>(input_d, output_d, partialSums_d, N); break;
        case 3: scan_double_kernel   <<<grid, BLOCK_DIM>>>(input_d, output_d, partialSums_d, N); break;
        case 4: scan_exclusive_kernel<<<grid, BLOCK_DIM>>>(input_d, output_d, partialSums_d, N); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

// 세 단계를 한 번 돌린다.
static void run_once(int which, unsigned int grid, unsigned int numBlocks,
                     float* input_d, float* output_d, float* partialSums_d,
                     unsigned int N) {
    launch_stage1(which, grid, input_d, output_d, partialSums_d, N);
    scan_partials_kernel<<<1, BLOCK_DIM>>>(partialSums_d, numBlocks);
    CUDA_CHECK(cudaGetLastError());
    add_offsets_kernel<<<grid, BLOCK_DIM>>>(output_d, partialSums_d, N);
    CUDA_CHECK(cudaGetLastError());
}

int main(int argc, char** argv) {

    unsigned int N = (argc > 1) ? (unsigned int)strtoul(argv[1], NULL, 0) : (1u << 20);

    // 슬라이드 커널들에는 경계 검사가 없다.
    if (N == 0 || N % BLOCK_DIM != 0) {
        fprintf(stderr, "N은 BLOCK_DIM(%d)의 배수여야 한다 (받은 값: %u)\n", BLOCK_DIM, N);
        return 1;
    }
    // 2단계를 블록 하나로 처리하므로 블록 수가 BLOCK_DIM을 넘으면 안 된다.
    if (N > (unsigned int)BLOCK_DIM*BLOCK_DIM) {
        fprintf(stderr, "N은 BLOCK_DIM*BLOCK_DIM(%d) 이하여야 한다 (받은 값: %u)\n",
                BLOCK_DIM*BLOCK_DIM, N);
        return 1;
    }

    printf("N = %u, BLOCK_DIM = %d\n", N, BLOCK_DIM);

    size_t bytes = (size_t)N*sizeof(float);
    unsigned int numBlocks = N/BLOCK_DIM;

    float* input   = (float*)malloc(bytes);
    float* output  = (float*)malloc(bytes);
    float* ref_inc = (float*)malloc(bytes);
    float* ref_exc = (float*)malloc(bytes);
    init_input(input, N, 1u);
    scan_cpu_inclusive(input, ref_inc, N);
    scan_cpu_exclusive(input, ref_exc, N);

    float *input_d, *output_d, *partialSums_d;
    CUDA_CHECK(cudaMalloc((void**) &input_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &output_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &partialSums_d, (size_t)numBlocks*sizeof(float)));
    CUDA_CHECK(cudaMemcpy(input_d, input, bytes, cudaMemcpyHostToDevice));

    Timer timer;

    for (int k = 0; k < NUM_KERNELS; ++k) {
        // 미구현 판정은 1단계 출력만 보고 한다.
        // 2, 3단계가 앞선 블록의 합을 더해 버리면 안 채운 상태의 흔적이 지워진다.
        CUDA_CHECK(cudaMemset(output_d, 0, bytes));
        launch_stage1(k, numBlocks, input_d, output_d, partialSums_d, N);
        CUDA_CHECK(cudaDeviceSynchronize());
        CUDA_CHECK(cudaMemcpy(output, output_d, bytes, cudaMemcpyDeviceToHost));
        if (looks_unimplemented(input, output, N)) {
            printf("%-9s : (미구현)\n", KERNEL_NAMES[k]);
            continue;
        }

        // 예열
        CUDA_CHECK(cudaMemset(output_d, 0, bytes));
        run_once(k, numBlocks, numBlocks, input_d, output_d, partialSums_d, N);
        CUDA_CHECK(cudaDeviceSynchronize());

        // 측정 — N이 작아 1회 측정은 흔들린다. 여러 번 돌려 평균을 낸다.
        timer.start();
        for (int r = 0; r < REPEATS; ++r) {
            run_once(k, numBlocks, numBlocks, input_d, output_d, partialSums_d, N);
        }
        float ms = timer.stop()/REPEATS;

        CUDA_CHECK(cudaMemcpy(output, output_d, bytes, cudaMemcpyDeviceToHost));

        // exclusive 는 참조가 다르다.
        const float* ref = (k == 4) ? ref_exc : ref_inc;
        long long idx = first_mismatch(ref, output, N, 1e-3f);

        if (idx < 0) {
            printf("%-9s : %6.3f ms   PASS\n", KERNEL_NAMES[k], ms);
        } else {
            printf("%-9s : %6.3f ms   FAIL   첫 불일치 idx=%lld  기대 %.6f  실제 %.6f\n",
                   KERNEL_NAMES[k], ms, idx, ref[idx], output[idx]);
        }
    }

    free(input); free(output); free(ref_inc); free(ref_exc);
    CUDA_CHECK(cudaFree(input_d));
    CUDA_CHECK(cudaFree(output_d));
    CUDA_CHECK(cudaFree(partialSums_d));
    return 0;
}
