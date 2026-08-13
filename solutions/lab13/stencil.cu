// lab13 — 3D stencil 최적화 사다리
// 채울 곳은 stencil_register_kernel 하나뿐이다. 나머지 세 커널은 완성되어 있다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"

// 7점 stencil 계수. 슬라이드는 C0~C6 을 상수로만 두고 값을 정하지 않는다.
// 여기서는 합이 1이 되도록 잡았다. 그래야 여러 번 적용해도 값이 발산하지 않아
// 검증에서 다루기 쉽다.
#define C0 0.4f
#define C1 0.1f
#define C2 0.1f
#define C3 0.1f
#define C4 0.1f
#define C5 0.1f
#define C6 0.1f

// ---------------------------------------------------------------------------
// 1단계 — 슬라이드 8: Stencil Code (완성)
//
// 타일링이 없다. 스레드 하나가 출력 한 점을 맡고 입력을 전역 메모리에서
// 일곱 번 읽는다. 이웃한 스레드끼리 같은 값을 다시 읽는 것이 그대로 낭비다.
// ---------------------------------------------------------------------------
#define BLOCK_DIM 8

__global__ void stencil_basic_kernel(float* in, float* out, unsigned int N) {
    unsigned int i = blockIdx.z*blockDim.z + threadIdx.z;
    unsigned int j = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int k = blockIdx.x*blockDim.x + threadIdx.x;
    if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1&& k >= 1 && k < N - 1) {
        out[i*N*N + j*N + k] = C0*in[i*N*N + j*N + k]
                             + C1*in[i*N*N + j*N + (k - 1)]
                             + C2*in[i*N*N + j*N + (k + 1)]
                             + C3*in[i*N*N + (j - 1)*N + k]
                             + C4*in[i*N*N + (j + 1)*N + k]
                             + C5*in[(i - 1)*N*N + j*N + k]
                             + C6*in[(i + 1)*N*N + j*N + k];
    }
}

// ---------------------------------------------------------------------------
// 2단계 — 슬라이드 17: 3D 공유 메모리 타일링 (완성)
//
// IN_TILE_DIM 은 공유 메모리 배열의 크기라 컴파일 시점에 정해져야 한다.
// 값을 바꾸려면 다시 빌드해야 한다.  make TILE=10  처럼 넘긴다.
// (Makefile 이 -DIN_TILE_DIM=10 으로 바꿔 준다)
//
// 블록이 3D 라 스레드 수가 IN_TILE_DIM^3 이다. 이 값이 1024 를 넘으면
// 실행할 수 없다. 슬라이드 19~22 가 말하는 한계가 이것이다.
// ---------------------------------------------------------------------------
#ifndef IN_TILE_DIM
#define IN_TILE_DIM 8
#endif
#define OUT_TILE_DIM (IN_TILE_DIM - 2)

__global__ void stencil_tiled_kernel(float* in, float* out, unsigned int N) {

    int i = blockIdx.z*OUT_TILE_DIM + threadIdx.z - 1;
    int j = blockIdx.y*OUT_TILE_DIM + threadIdx.y - 1;
    int k = blockIdx.x*OUT_TILE_DIM + threadIdx.x - 1;

    __shared__ float in_s[IN_TILE_DIM][IN_TILE_DIM][IN_TILE_DIM];
    if(i >= 0 && i < N && j >= 0 && j < N && k >= 0 && k < N) {
        in_s[threadIdx.z][threadIdx.y][threadIdx.x] = in[i*N*N + j*N + k];
    }
    __syncthreads();

    if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1 && k >= 1 && k < N - 1) {
         if(threadIdx.z >= 1 && threadIdx.z < IN_TILE_DIM - 1 && threadIdx.y >= 1
            && threadIdx.y < IN_TILE_DIM - 1 && threadIdx.x >= 1 && threadIdx.x < IN_TILE_DIM - 1) {
            out[i*N*N + j*N + k] = C0*in_s[threadIdx.z][threadIdx.y][threadIdx.x]
                                 + C1*in_s[threadIdx.z][threadIdx.y][threadIdx.x - 1]
                                 + C2*in_s[threadIdx.z][threadIdx.y][threadIdx.x + 1]
                                 + C3*in_s[threadIdx.z][threadIdx.y - 1][threadIdx.x]
                                 + C4*in_s[threadIdx.z][threadIdx.y + 1][threadIdx.x]
                                 + C5*in_s[threadIdx.z - 1][threadIdx.y][threadIdx.x]
                                 + C6*in_s[threadIdx.z + 1][threadIdx.y][threadIdx.x];
        }
    }

}

// 호스트 코드가 쓸 값. 아래에서 IN_TILE_DIM 을 2D 커널용으로 다시 정의하므로
// 그 전에 붙잡아 둔다.
static const unsigned int TILED_IN_DIM  = IN_TILE_DIM;
static const unsigned int TILED_OUT_DIM = OUT_TILE_DIM;

#undef OUT_TILE_DIM
#undef IN_TILE_DIM

// ---------------------------------------------------------------------------
// 3, 4단계는 블록이 2D 다. z 방향으로 한 슬라이스씩 행진하면서 재사용한다.
// 블록이 2D 라 스레드 수가 IN_TILE_DIM^2 이고, 32 로 잡아도 1024 개다.
// 3D 블록이었다면 8 을 넘길 수 없었던 자리다.
//
// 슬라이드 31, 32 는 이 값을 3D 타일링과 같은 이름(IN_TILE_DIM)으로 쓴다.
// 커널 안에서 학생이 보는 이름을 슬라이드와 같게 두려고, 매크로를 지웠다가
// 값만 바꿔 다시 정의했다. 커널 본체는 슬라이드 그대로다.
// ---------------------------------------------------------------------------
#ifndef IN_TILE_DIM_2D
#define IN_TILE_DIM_2D 32
#endif
#define IN_TILE_DIM  IN_TILE_DIM_2D
#define OUT_TILE_DIM (IN_TILE_DIM - 2)

// ---------------------------------------------------------------------------
// 3단계 — 슬라이드 31: Thread coarsening + tile slicing (완성)
//
// 공유 메모리 타일 세 장(이전/현재/다음 슬라이스)을 들고 z 방향으로 행진한다.
// 슬라이드 28 에도 같은 코드가 있으나 오타가 있다. 31 이 고친 판본이다.
// ---------------------------------------------------------------------------
__global__ void stencil_coarse_kernel(float* in, float* out, unsigned int N) {

    int iStart = blockIdx.z*OUT_TILE_DIM;
    int j = blockIdx.y*OUT_TILE_DIM + threadIdx.y - 1;
    int k = blockIdx.x*OUT_TILE_DIM + threadIdx.x - 1;

    __shared__ float inPrev_s[IN_TILE_DIM][IN_TILE_DIM];
    __shared__ float inCurr_s[IN_TILE_DIM][IN_TILE_DIM];
    __shared__ float inNext_s[IN_TILE_DIM][IN_TILE_DIM];
    if(iStart - 1 >= 0 && iStart - 1 < N && j >= 0 && j < N && k >= 0 && k < N) {
        inPrev_s[threadIdx.y][threadIdx.x] = in[(iStart - 1)*N*N + j*N + k];
    }
    if(iStart >= 0 && iStart < N && j >= 0 && j < N && k >= 0 && k < N) {
        inCurr_s[threadIdx.y][threadIdx.x] = in[iStart*N*N + j*N + k];
    }

    for(int i = iStart; i < iStart + OUT_TILE_DIM; ++i) {
        if(i + 1 >= 0 && i + 1 < N && j >= 0 && j < N && k >= 0 && k < N) {
            inNext_s[threadIdx.y][threadIdx.x] = in[(i + 1)*N*N + j*N + k];
        }
        __syncthreads();
        if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1 && k >= 1 && k < N - 1) {
            if(threadIdx.y >= 1 && threadIdx.y < IN_TILE_DIM - 1
               && threadIdx.x >= 1 && threadIdx.x < IN_TILE_DIM - 1) {
                out[i*N*N + j*N + k] = C0*inCurr_s[threadIdx.y][threadIdx.x]
                                     + C1*inCurr_s[threadIdx.y][threadIdx.x - 1]
                                     + C2*inCurr_s[threadIdx.y][threadIdx.x + 1]
                                     + C3*inCurr_s[threadIdx.y - 1][threadIdx.x]
                                     + C4*inCurr_s[threadIdx.y + 1][threadIdx.x]
                                     + C5*inPrev_s[threadIdx.y][threadIdx.x]
                                     + C6*inNext_s[threadIdx.y][threadIdx.x];
            }
        }
        __syncthreads();
        inPrev_s[threadIdx.y][threadIdx.x] = inCurr_s[threadIdx.y][threadIdx.x];
        inCurr_s[threadIdx.y][threadIdx.x] = inNext_s[threadIdx.y][threadIdx.x];
    }

}

// ---------------------------------------------------------------------------
// 4단계 — 슬라이드 32: Register tiling. 여기를 채운다
//
// 지금 이 파일에 들어 있는 것은 3단계(슬라이드 31)와 똑같은 코드다.
// 그래서 지금 빌드해도 결과는 맞게 나온다. 다만 공유 메모리를 세 장 쓴다.
//
// 과제는 이것을 슬라이드 32 로 바꾸는 것이다. 두 슬라이드를 나란히 놓고
// 다른 곳만 고치면 된다. 고칠 곳은 네 군데뿐이고, 3D 인덱싱과 경계 검사는
// 건드리지 않는다.
//
// 생각의 요점: inPrev_s 와 inNext_s 는 스레드가 자기 자리([threadIdx.y]
// [threadIdx.x]) 하나만 읽는다. 옆 스레드의 값을 볼 일이 없다. 그렇다면
// 그 두 장은 공유 메모리에 있을 이유가 없다. 각자 레지스터에 들고 있으면 된다.
// inCurr_s 는 다르다. C1~C4 항이 옆자리를 읽으므로 공유 메모리로 남아야 한다.
//
// 제대로 고쳤는지는 실행하면 바로 보인다. "공유메모리/블록" 열이 세 장에서
// 한 장으로 줄어든다. 줄지 않았으면 (미구현)으로 표시된다.
//
// 다만 "SM당 블록" 은 이 GPU 에서 늘어나지 않는다. 무엇이 막고 있는지는
// 옆의 "공유MEM 한계" 열과 비교해 보라. README 의 토론 문제 2번이다.
// ---------------------------------------------------------------------------
__global__ void stencil_register_kernel(float* in, float* out, unsigned int N) {

    int iStart = blockIdx.z*OUT_TILE_DIM;
    int j = blockIdx.y*OUT_TILE_DIM + threadIdx.y - 1;
    int k = blockIdx.x*OUT_TILE_DIM + threadIdx.x - 1;

    float inPrev;
    __shared__ float inCurr_s[IN_TILE_DIM][IN_TILE_DIM];
    float inNext;
    if(iStart - 1 >= 0 && iStart - 1 < N && j >= 0 && j < N && k >= 0 && k < N) {
        inPrev = in[(iStart - 1)*N*N + j*N + k];
    }
    if(iStart >= 0 && iStart < N && j >= 0 && j < N && k >= 0 && k < N) {
        inCurr_s[threadIdx.y][threadIdx.x] = in[iStart*N*N + j*N + k];
    }

    for(int i = iStart; i < iStart + OUT_TILE_DIM; ++i) {
        if(i + 1 >= 0 && i + 1 < N && j >= 0 && j < N && k >= 0 && k < N) {
            inNext = in[(i + 1)*N*N + j*N + k];
        }
        __syncthreads();
        if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1 && k >= 1 && k < N - 1) {
            if(threadIdx.y >= 1 && threadIdx.y < IN_TILE_DIM - 1
               && threadIdx.x >= 1 && threadIdx.x < IN_TILE_DIM - 1) {
                out[i*N*N + j*N + k] = C0*inCurr_s[threadIdx.y][threadIdx.x]
                                     + C1*inCurr_s[threadIdx.y][threadIdx.x - 1]
                                     + C2*inCurr_s[threadIdx.y][threadIdx.x + 1]
                                     + C3*inCurr_s[threadIdx.y - 1][threadIdx.x]
                                     + C4*inCurr_s[threadIdx.y + 1][threadIdx.x]
                                     + C5*inPrev
                                     + C6*inNext;
            }
        }
        __syncthreads();
        inPrev = inCurr_s[threadIdx.y][threadIdx.x];
        inCurr_s[threadIdx.y][threadIdx.x] = inNext;
    }

}

static const unsigned int COARSE_IN_DIM  = IN_TILE_DIM;
static const unsigned int COARSE_OUT_DIM = OUT_TILE_DIM;

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

#define NUM_KERNELS 4
#define REPEATS     20
static const char* KERNEL_NAMES[NUM_KERNELS] = {
    "basic", "tiled", "coarse", "register"
};

// 입력을 [0, 1) 균등난수로 채운다. 시드가 같으면 항상 같은 값이 나온다.
static void init_input(float* in, size_t n, unsigned int seed) {
    unsigned int s = seed;
    for (size_t i = 0; i < n; ++i) {
        s = s*1664525u + 1013904223u;                 // 선형 합동 생성기
        in[i] = (float)(s >> 8)/16777216.0f;          // 상위 24비트를 2^24로 나눈다
    }
}

// CPU 참조. 경계(i, j, k 가 0 또는 N-1)는 커널이 아예 쓰지 않으므로
// 참조도 만들지 않는다. 내부 점 (N-2)^3 개만 차례로 담는다.
//
// 누적은 double 로 한다. float 로 일곱 항을 더하면 참조 자신이 흔들려
// 기준 구실을 못 한다. 리덕션 랩에서 확인한 것과 같은 이유다.
static void stencil_cpu_interior(const float* in, float* ref, unsigned int N) {
    size_t t = 0;
    for (unsigned int i = 1; i < N - 1; ++i) {
        for (unsigned int j = 1; j < N - 1; ++j) {
            for (unsigned int k = 1; k < N - 1; ++k) {
                double v = (double)C0*in[(size_t)i*N*N + j*N + k]
                         + (double)C1*in[(size_t)i*N*N + j*N + (k - 1)]
                         + (double)C2*in[(size_t)i*N*N + j*N + (k + 1)]
                         + (double)C3*in[(size_t)i*N*N + (j - 1)*N + k]
                         + (double)C4*in[(size_t)i*N*N + (j + 1)*N + k]
                         + (double)C5*in[(size_t)(i - 1)*N*N + j*N + k]
                         + (double)C6*in[(size_t)(i + 1)*N*N + j*N + k];
                ref[t++] = (float)v;
            }
        }
    }
}

// 커널 출력에서 내부 점만 뽑아 참조와 같은 순서로 담는다.
static void gather_interior(const float* out, float* got, unsigned int N) {
    size_t t = 0;
    for (unsigned int i = 1; i < N - 1; ++i) {
        for (unsigned int j = 1; j < N - 1; ++j) {
            for (unsigned int k = 1; k < N - 1; ++k) {
                got[t++] = out[(size_t)i*N*N + j*N + k];
            }
        }
    }
}

// 커널이 실제로 쓰는 정적 공유 메모리 바이트. 손으로 센 값이 아니라
// 컴파일된 커널에 물어본 값이다. register 버전을 제대로 고쳤는지도
// 이 값으로 판정한다.
static size_t static_shared_bytes(const void* kernel) {
    cudaFuncAttributes attr;
    if (cudaFuncGetAttributes(&attr, kernel) != cudaSuccess) {
        cudaGetLastError();
        return 0;
    }
    return attr.sharedSizeBytes;
}

// 공유 메모리만 따졌을 때 SM 에 몇 블록이 들어갈 수 있는가.
// 실제 SM당 블록 수와 나란히 놓으면 무엇이 한계인지 바로 보인다.
static int blocks_by_shared(size_t smem_per_block) {
    int device = 0, smem_per_sm = 0;
    if (smem_per_block == 0) return -1;                 // 제한 없음
    cudaGetDevice(&device);
    if (cudaDeviceGetAttribute(&smem_per_sm, cudaDevAttrMaxSharedMemoryPerMultiprocessor,
                               device) != cudaSuccess) {
        cudaGetLastError();
        return 0;
    }
    return (int)(smem_per_sm/smem_per_block);
}

static int blocks_per_sm(const void* kernel, int blockSize, size_t smem) {
    int n = 0;
    if (cudaOccupancyMaxActiveBlocksPerMultiprocessor(&n, kernel, blockSize, smem)
        != cudaSuccess) {
        cudaGetLastError();
        return 0;
    }
    return n;
}

static unsigned int ceil_div(unsigned int a, unsigned int b) { return (a + b - 1)/b; }

int main(int argc, char** argv) {

    unsigned int N = (argc > 1) ? (unsigned int)strtoul(argv[1], NULL, 0) : 256;

    if (N < 8) {
        fprintf(stderr, "N은 8 이상이어야 한다 (받은 값: %u)\n", N);
        return 1;
    }
    // 배열 두 개가 VRAM 에 들어가야 한다. 384^3 이면 하나에 216MB 다.
    if (N > 384) {
        fprintf(stderr, "N은 384 이하로 한다 (VRAM, 받은 값: %u)\n", N);
        return 1;
    }
    // 3D 블록은 스레드 수가 IN_TILE_DIM^3 이다. 1024 를 넘으면 실행할 수 없다.
    if (TILED_IN_DIM*TILED_IN_DIM*TILED_IN_DIM > 1024) {
        fprintf(stderr,
                "IN_TILE_DIM=%u 는 3D 블록에서 %u 스레드가 되어 블록당 최대 1024 를 넘는다.\n"
                "슬라이드 19~22 가 말하는 한계가 이것이다.\n",
                TILED_IN_DIM, TILED_IN_DIM*TILED_IN_DIM*TILED_IN_DIM);
        return 1;
    }

    size_t count = (size_t)N*N*N;
    size_t bytes = count*sizeof(float);
    size_t inner = (size_t)(N - 2)*(N - 2)*(N - 2);
    double MB    = bytes/(1024.0*1024.0);

    // 배열 두 개가 L2 를 넘어야 캐시가 아니라 메모리를 재게 된다.
    int device = 0, l2 = 0;
    cudaGetDevice(&device);
    cudaDeviceGetAttribute(&l2, cudaDevAttrL2CacheSize, device);
    double l2MB = l2/(1024.0*1024.0);
    printf("N = %u  (입력 %.1f MB + 출력 %.1f MB", N, MB, MB);
    if (l2 > 0) printf(", L2 %.0fMB %s", l2MB, (2*MB > l2MB) ? "초과" : "이내");
    printf(")\n");
    printf("IN_TILE_DIM = %u (3D 타일링, OUT_TILE_DIM = %u),  "
           "%u (2D 슬라이스, OUT_TILE_DIM = %u)\n",
           TILED_IN_DIM, TILED_OUT_DIM, COARSE_IN_DIM, COARSE_OUT_DIM);

    float* in  = (float*)malloc(bytes);
    float* out = (float*)malloc(bytes);
    float* ref = (float*)malloc(inner*sizeof(float));
    float* got = (float*)malloc(inner*sizeof(float));
    if (!in || !out || !ref || !got) {
        fprintf(stderr, "호스트 메모리가 부족하다\n");
        return 1;
    }
    init_input(in, count, 1u);
    stencil_cpu_interior(in, ref, N);

    float *in_d, *out_d;
    CUDA_CHECK(cudaMalloc((void**) &in_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &out_d, bytes));
    CUDA_CHECK(cudaMemcpy(in_d, in, bytes, cudaMemcpyHostToDevice));

    // 실행 구성 — 커널마다 블록 모양이 다르다.
    dim3 block[NUM_KERNELS], grid[NUM_KERNELS];
    int  threads[NUM_KERNELS];

    block[0] = dim3(BLOCK_DIM, BLOCK_DIM, BLOCK_DIM);
    grid[0]  = dim3(ceil_div(N, BLOCK_DIM), ceil_div(N, BLOCK_DIM), ceil_div(N, BLOCK_DIM));
    threads[0] = BLOCK_DIM*BLOCK_DIM*BLOCK_DIM;

    block[1] = dim3(TILED_IN_DIM, TILED_IN_DIM, TILED_IN_DIM);
    grid[1]  = dim3(ceil_div(N, TILED_OUT_DIM), ceil_div(N, TILED_OUT_DIM),
                    ceil_div(N, TILED_OUT_DIM));
    threads[1] = TILED_IN_DIM*TILED_IN_DIM*TILED_IN_DIM;

    // 2D 블록. z 방향은 블록 하나가 OUT_TILE_DIM 개 슬라이스를 맡는다.
    for (int k = 2; k < 4; ++k) {
        block[k] = dim3(COARSE_IN_DIM, COARSE_IN_DIM);
        grid[k]  = dim3(ceil_div(N, COARSE_OUT_DIM), ceil_div(N, COARSE_OUT_DIM),
                        ceil_div(N, COARSE_OUT_DIM));
        threads[k] = COARSE_IN_DIM*COARSE_IN_DIM;
    }

    const void* kfunc[NUM_KERNELS] = {
        (const void*)stencil_basic_kernel,
        (const void*)stencil_tiled_kernel,
        (const void*)stencil_coarse_kernel,
        (const void*)stencil_register_kernel
    };

    int max_threads_per_sm = 0;
    cudaDeviceGetAttribute(&max_threads_per_sm, cudaDevAttrMaxThreadsPerMultiProcessor, device);

    size_t smem[NUM_KERNELS];
    int    bpsm[NUM_KERNELS];
    for (int k = 0; k < NUM_KERNELS; ++k) {
        smem[k] = static_shared_bytes(kfunc[k]);
        bpsm[k] = blocks_per_sm(kfunc[k], threads[k], 0);
    }

    // register 버전을 고치지 않았으면 공유 메모리가 coarse 와 똑같다.
    // 그때만 (미구현)으로 본다. 타일 세 장이 한 장으로 줄어드는 것이
    // 이 과제의 전부이므로, 이 값이 곧 채점 기준이다.
    int register_done = (smem[3] < smem[2]);

    Timer timer;
    float ms[NUM_KERNELS];
    int   ok[NUM_KERNELS];

    for (int k = 0; k < NUM_KERNELS; ++k) {
        CUDA_CHECK(cudaMemset(out_d, 0, bytes));

        // 예열
        switch (k) {
            case 0: stencil_basic_kernel   <<<grid[k], block[k]>>>(in_d, out_d, N); break;
            case 1: stencil_tiled_kernel   <<<grid[k], block[k]>>>(in_d, out_d, N); break;
            case 2: stencil_coarse_kernel  <<<grid[k], block[k]>>>(in_d, out_d, N); break;
            case 3: stencil_register_kernel<<<grid[k], block[k]>>>(in_d, out_d, N); break;
        }
        CUDA_CHECK(cudaGetLastError());
        CUDA_CHECK(cudaDeviceSynchronize());

        timer.start();
        for (int r = 0; r < REPEATS; ++r) {
            switch (k) {
                case 0: stencil_basic_kernel   <<<grid[k], block[k]>>>(in_d, out_d, N); break;
                case 1: stencil_tiled_kernel   <<<grid[k], block[k]>>>(in_d, out_d, N); break;
                case 2: stencil_coarse_kernel  <<<grid[k], block[k]>>>(in_d, out_d, N); break;
                case 3: stencil_register_kernel<<<grid[k], block[k]>>>(in_d, out_d, N); break;
            }
        }
        ms[k] = timer.stop()/REPEATS;

        CUDA_CHECK(cudaMemcpy(out, out_d, bytes, cudaMemcpyDeviceToHost));
        gather_interior(out, got, N);
        ok[k] = compare_float(ref, got, inner, 1e-3f);
    }

    // 유효 트래픽은 읽기 + 쓰기다. 최소 트래픽 기준이라 겹쳐 읽는 부분은 세지 않는다.
    // 낭비가 많은 버전일수록 이 값이 낮게 나오는 것이 의도한 동작이다.
    double traffic = 2.0*(double)count*sizeof(float);

    // 이론 대비 몇 %까지 갔는지가 이 랩의 핵심 숫자다. basic 이 이미 이론의
    // 대부분을 쓰고 있으면, 그 위에서 최적화로 더 얻을 것이 남아 있지 않다.
    float bw_peak = theoretical_bandwidth_GBps();
    if (bw_peak > 0.0f) printf("이론 대역폭 = %.1f GB/s\n", bw_peak);

    printf("\n");
    printf("%-9s %10s %9s %9s %14s %11s %13s %6s\n",
           "커널", "시간", "GB/s", "이론대비", "공유메모리/블록", "SM당 블록",
           "공유MEM 한계", "검증");
    for (int k = 0; k < NUM_KERNELS; ++k) {
        int lim = blocks_by_shared(smem[k]);
        char limbuf[16];
        if (lim < 0) snprintf(limbuf, sizeof(limbuf), "%s", "제한없음");
        else         snprintf(limbuf, sizeof(limbuf), "%d", lim);

        if (k == 3 && !register_done) {
            printf("%-9s %10s %9s %9s %12zu B %11d %13s   (미구현)\n",
                   KERNEL_NAMES[k], "-", "-", "-", smem[k], bpsm[k], limbuf);
            continue;
        }
        double gbps = traffic/(ms[k]/1e3)/1e9;
        char pctbuf[16];
        if (bw_peak > 0.0f) snprintf(pctbuf, sizeof(pctbuf), "%.1f%%", 100.0*gbps/bw_peak);
        else                snprintf(pctbuf, sizeof(pctbuf), "%s", "-");
        printf("%-9s %7.2f ms %9.1f %9s %12zu B %11d %13s %6s\n",
               KERNEL_NAMES[k], ms[k], gbps, pctbuf, smem[k], bpsm[k], limbuf,
               ok[k] ? "PASS" : "FAIL");
    }
    printf("\n블록당 스레드: basic %d, tiled %d, coarse/register %d   (SM당 최대 %d 스레드)\n",
           threads[0], threads[1], threads[2], max_threads_per_sm);
    printf("\"SM당 블록\" 은 실제 값이고, \"공유MEM 한계\" 는 공유 메모리만 따졌을 때\n");
    printf("들어갈 수 있는 블록 수다. 둘이 다르면 공유 메모리가 아닌 다른 것이 막고 있다.\n");

    if (!register_done) {
        printf("\nregister 커널의 공유 메모리가 coarse 와 같다(%zu B).\n", smem[3]);
        printf("아직 TODO 를 안 채운 것이다. 슬라이드 32 를 보고 타일 두 장을\n");
        printf("레지스터로 옮겨라. 제대로 고치면 이 값이 %zu B 로 줄어든다.\n",
               smem[2]/3);
    }

    free(in); free(out); free(ref); free(got);
    CUDA_CHECK(cudaFree(in_d)); CUDA_CHECK(cudaFree(out_d));

    int all_ok = 1;
    for (int k = 0; k < NUM_KERNELS; ++k) if (!ok[k]) all_ok = 0;
    return (all_ok && register_done) ? 0 : 1;
}
