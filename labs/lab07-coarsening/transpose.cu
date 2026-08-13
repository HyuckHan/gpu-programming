// lab07 — 전치로 보는 coalescing
//
// 채울 곳이 없다. 전부 완성되어 있다. 이 랩에서 학생이 할 일은 측정과 해석이다.
// 전치는 강의 슬라이드에 없는 코드라 TODO 로 내지 않는다.
//
// 행렬곱으로는 coalescing 을 보여줄 수 없다. naive 행렬곱의 B[i*N + col] 은
// 이미 연속 접근이고 A[row*N + i] 는 워프 전체가 같은 값을 읽는 브로드캐스트다.
// 접근 횟수만 많을 뿐 패턴이 나쁘지 않아 L2 가 상당 부분을 흡수한다.
//
// 전치는 다르다. 읽기와 쓰기 중 한쪽은 반드시 stride-N 이 된다.
#include <stdio.h>
#include <stdlib.h>
#include "common.cuh"

// ---------------------------------------------------------------------------
// 1) naive — 읽기는 연속, 쓰기는 stride-N
//
// 커널은 한 줄뿐이다. 그런데 이 커널의 속도는 blockDim 을 어떻게 잡느냐에 따라
// 두 배까지 달라진다. 코드가 아니라 워프가 무엇을 하는지가 성능을 정한다.
//
// blockDim.x = 32 일 때, 한 워프의 32개 스레드는 threadIdx.x 만 다르다.
//   읽기  in[row*N + col]   : col 이 1씩 늘어난다 → 연속된 128바이트 한 덩어리
//   쓰기  out[col*N + row]  : col 이 1씩 늘어나면 주소가 N*4 바이트씩 뛴다
//                             → 32개의 서로 다른 캐시 라인
// 쓰기 한 번에 32개 라인을 건드리는데 각 라인에서 쓰는 것은 4바이트뿐이다.
// ---------------------------------------------------------------------------
__global__ void transpose_naive_kernel(float* in, float* out, unsigned int N) {

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int col = blockIdx.x*blockDim.x + threadIdx.x;

    out[col*N + row] = in[row*N + col];

}

// ---------------------------------------------------------------------------
// 2) tiled — 공유 메모리를 거쳐 읽기·쓰기 모두 연속
//
// 타일 하나를 통째로 공유 메모리에 담고, 내보낼 때 담당 위치를 바꿔 잡는다.
// 전역 메모리 접근은 읽기도 쓰기도 threadIdx.x 방향으로 연속이다.
// 뒤집는 일은 공유 메모리 안에서만 일어난다.
//
// TILE_DIM 은 공유 메모리 배열의 크기라 컴파일 시점에 정해져야 한다.
// lab06 과 같은 이유로 커널을 template 로 두었다.
// ---------------------------------------------------------------------------
template <unsigned int TILE_DIM>
__global__ void transpose_tiled_kernel(float* in, float* out, unsigned int N) {

    __shared__ float tile_s[TILE_DIM][TILE_DIM];

    // 읽기 — 입력에서 이 블록이 맡은 타일의 위치
    unsigned int row = blockIdx.y*TILE_DIM + threadIdx.y;
    unsigned int col = blockIdx.x*TILE_DIM + threadIdx.x;
    tile_s[threadIdx.y][threadIdx.x] = in[row*N + col];

    __syncthreads();

    // 쓰기 — 출력에서의 타일 위치는 blockIdx.x 와 blockIdx.y 가 뒤바뀐 자리다.
    // 전치는 공유 메모리를 읽는 첨자 순서로 끝낸다.
    row = blockIdx.x*TILE_DIM + threadIdx.y;
    col = blockIdx.y*TILE_DIM + threadIdx.x;
    out[row*N + col] = tile_s[threadIdx.x][threadIdx.y];

}

// ---------------------------------------------------------------------------
// 호스트 코드 (완성)
// ---------------------------------------------------------------------------

// 커널을 몇 번 돌려 평균을 낸다. 전치는 한 번이 1ms 안팎이라
// 한 번만 재면 실행마다 값이 눈에 띄게 흔들린다.
#define NUM_ITERS 20

// 기준선 naive 의 블록 모양. TILE_DIM 을 바꿔도 이 값은 고정이다.
// 기준선까지 같이 흔들리면 배속이라는 숫자를 해석할 수 없다.
// x 를 32 로 두는 것은 워프 하나가 가로로 32칸을 덮게 하려는 것이다.
#define NAIVE_X 32
#define NAIVE_Y 32

// 비교용으로 한 번 더 재는 블록 모양. 커널은 위와 같은 것을 쓴다.
#define ALT_X 16
#define ALT_Y 16

// N x N 행렬을 -0.5 ~ 0.5 난수로 채운다.
// 시드가 같으면 어느 PC에서 몇 번을 돌려도 같은 값이 나온다(재현 가능).
static void init_matrix(float* M, unsigned int N, unsigned int seed) {
    unsigned int s = seed;
    for (unsigned int i = 0; i < N*N; ++i) {
        s = s*1664525u + 1013904223u;                     // 선형 합동 생성기
        M[i] = (float)(s >> 16)/65536.0f - 0.5f;
    }
}

// CPU 참조 전치. lab01 워밍업에서 직접 작성한 함수와 같은 것이다.
static void mat_transpose(const float* A, float* B, int rows, int cols) {
    for (int row = 0; row < rows; ++row) {
        for (int col = 0; col < cols; ++col) {
            B[col*rows + row] = A[row*cols + col];
        }
    }
}

static void launch_tiled(unsigned int tile_dim, dim3 grid, dim3 block,
                         float* in_d, float* out_d, unsigned int N) {
    switch (tile_dim) {
        case  8: transpose_tiled_kernel< 8><<<grid, block>>>(in_d, out_d, N); break;
        case 16: transpose_tiled_kernel<16><<<grid, block>>>(in_d, out_d, N); break;
        case 32: transpose_tiled_kernel<32><<<grid, block>>>(in_d, out_d, N); break;
    }
    CUDA_CHECK(cudaGetLastError());
}

// L2 크기는 GPU마다 다르다(4060 24MB, 4060 Ti 32MB). 하드코딩하지 않고 조회한다.
// 얻지 못하면 0을 돌려주므로 호출부에서 그 줄을 건너뛴다.
static float l2_cache_MB(void) {
    int device = 0;
    if (cudaGetDevice(&device) != cudaSuccess) { cudaGetLastError(); return 0.0f; }
    int bytes = 0;
    if (cudaDeviceGetAttribute(&bytes, cudaDevAttrL2CacheSize, device) != cudaSuccess) {
        cudaGetLastError();
        return 0.0f;
    }
    return bytes/(1024.0f*1024.0f);
}

int main(int argc, char** argv) {

    unsigned int N        = (argc > 1) ? (unsigned int)atoi(argv[1]) : 4096;
    unsigned int TILE_DIM = (argc > 2) ? (unsigned int)atoi(argv[2]) : 32;

    if (TILE_DIM != 8 && TILE_DIM != 16 && TILE_DIM != 32) {
        fprintf(stderr, "TILE_DIM은 8, 16, 32 중 하나여야 한다 (받은 값: %u)\n", TILE_DIM);
        return 1;
    }
    // 두 커널 모두 경계 검사가 없다. 기준선 naive 가 32x32 고정이므로
    // N 은 TILE_DIM 과 32 양쪽의 배수여야 한다.
    if (N == 0 || N % TILE_DIM != 0 || N % NAIVE_X != 0 || N % NAIVE_Y != 0) {
        fprintf(stderr, "N은 TILE_DIM(=%u)과 %d의 배수여야 한다 (N=%u)\n",
                TILE_DIM, NAIVE_X, N);
        return 1;
    }
    if (N > 8192) {
        fprintf(stderr, "N은 8192 이하로 한다 (VRAM)\n");
        return 1;
    }

    size_t bytes = (size_t)N*N*sizeof(float);
    size_t count = (size_t)N*N;
    double MB    = bytes/(1024.0*1024.0);

    float l2 = l2_cache_MB();
    if (l2 > 0.0f) {
        printf("N = %u  (입력 %.1f MB + 출력 %.1f MB = %.1f MB, L2 %.0fMB %s)\n",
               N, MB, MB, 2*MB, l2, (2*MB > l2) ? "초과" : "이내");
        if (2*MB <= l2) {
            printf("  주의: 입출력이 L2 안에 들어간다. 아래 GB/s 는 L2 대역폭이라\n");
            printf("        이론 대비가 100%%를 넘을 수 있다. N을 키워서 다시 재라.\n");
        }
    } else {
        printf("N = %u  (입력 %.1f MB + 출력 %.1f MB = %.1f MB)\n", N, MB, MB, 2*MB);
    }
    printf("TILE_DIM = %u,  반복 %d회 평균\n", TILE_DIM, NUM_ITERS);

    float* in  = (float*)malloc(bytes);
    float* out = (float*)malloc(bytes);
    float* ref = (float*)malloc(bytes);
    init_matrix(in, N, 1u);
    mat_transpose(in, ref, N, N);

    float *in_d, *out_d;
    CUDA_CHECK(cudaMalloc((void**) &in_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &out_d, bytes));
    CUDA_CHECK(cudaMemcpy(in_d, in, bytes, cudaMemcpyHostToDevice));

    Timer timer;
    int ok = 1;

    // 커널 하나를 워밍업 후 NUM_ITERS 회 돌려 평균 ms 를 돌려준다.
    // 매번 결과를 되가져와 CPU 참조와 대조한다.
#define MEASURE(ms_out, launch)                                               \
    do {                                                                      \
        CUDA_CHECK(cudaMemset(out_d, 0, bytes));                              \
        launch;                                                               \
        CUDA_CHECK(cudaGetLastError());                                       \
        CUDA_CHECK(cudaDeviceSynchronize());                                  \
        timer.start();                                                        \
        for (int it_ = 0; it_ < NUM_ITERS; ++it_) { launch; }                 \
        (ms_out) = timer.stop()/NUM_ITERS;                                    \
        CUDA_CHECK(cudaMemcpy(out, out_d, bytes, cudaMemcpyDeviceToHost));    \
        ok = compare_float(ref, out, count, 1e-6f) && ok;                     \
    } while (0)

    // 기준선 naive — 32x32 고정. 워프 하나가 가로로 32칸을 덮는다.
    float ms_naive;
    MEASURE(ms_naive, (transpose_naive_kernel
            <<<dim3(N/NAIVE_X, N/NAIVE_Y), dim3(NAIVE_X, NAIVE_Y)>>>(in_d, out_d, N)));

    // 같은 커널을 16x16 으로. 코드는 한 글자도 다르지 않다.
    float ms_alt;
    MEASURE(ms_alt, (transpose_naive_kernel
            <<<dim3(N/ALT_X, N/ALT_Y), dim3(ALT_X, ALT_Y)>>>(in_d, out_d, N)));

    // tiled
    float ms_tiled;
    MEASURE(ms_tiled, launch_tiled(TILE_DIM, dim3(N/TILE_DIM, N/TILE_DIM),
                                   dim3(TILE_DIM, TILE_DIM), in_d, out_d, N));
#undef MEASURE

    // 유효 트래픽은 읽기 + 쓰기다. 전치는 원소 하나를 한 번 읽어 한 번 쓴다.
    double traffic = 2.0*(double)N*N*sizeof(float);
    float bw_peak = theoretical_bandwidth_GBps();

#define REPORT(label, ms)                                                     \
    do {                                                                      \
        double gbps = traffic/((ms)/1e3)/1e9;                                 \
        if (bw_peak > 0.0f)                                                   \
            printf("%-16s : %6.2f ms   %5.1f GB/s   (이론 대비 %4.1f%%)\n",   \
                   label, (ms), gbps, 100.0*gbps/bw_peak);                    \
        else                                                                  \
            printf("%-16s : %6.2f ms   %5.1f GB/s\n", label, (ms), gbps);     \
    } while (0)

    printf("\n");
    REPORT("naive 32x32", ms_naive);
    REPORT("naive 16x16", ms_alt);
    char tiled_label[32];
    snprintf(tiled_label, sizeof(tiled_label), "tiled %ux%u", TILE_DIM, TILE_DIM);
    REPORT(tiled_label, ms_tiled);
#undef REPORT

    printf("배속  : %6.2f x   (기준선 naive 32x32 대비)\n", ms_naive/ms_tiled);
    printf("정확성: %s\n", ok ? "PASS" : "FAIL");

    free(in); free(out); free(ref);
    CUDA_CHECK(cudaFree(in_d)); CUDA_CHECK(cudaFree(out_d));
    return ok ? 0 : 1;
}
