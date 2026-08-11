// 5주차 — 행렬곱 (naive)
// 채울 곳은 mm_kernel 본체 하나뿐이다. 나머지는 완성된 코드다.
#include <stdio.h>
#include <stdlib.h>
#include "../../common/common.cuh"

// ---------------------------------------------------------------------------
// 슬라이드 22 — Chapter 03, Example: Matrix-Matrix Multiplication
//
// 스레드 하나가 C의 원소 하나를 맡는다.
// N이 blockDim의 배수인 경우만 다루므로 경계 검사는 필요 없다.
// ---------------------------------------------------------------------------
__global__ void mm_kernel(float* A, float* B, float* C, unsigned int N) {

    // TODO: row, col 을 구한다 — 이 스레드가 담당할 C의 위치.
    //       blockIdx, blockDim, threadIdx 를 조합한다. y가 행, x가 열이다.

    // TODO: sum 을 0.0f 로 두고, i 를 0부터 N 전까지 돌며
    //         sum += A[row*N + i]*B[i*N + col];
    //       A는 row 행을 가로로 훑고, B는 col 열을 세로로 훑는다.

    // TODO: C[row*N + col] 에 sum 을 쓴다

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

// CPU 참조 행렬곱. 변수명은 위 mm_kernel과 같다.
// 1주차 워밍업(w01-c-warmup/warmup.c)에서 학생이 직접 작성한 함수와 같은 것이다.
// O(N^3)이라 N이 커지면 감당이 안 된다. 작은 N에서만 쓴다.
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

// N이 크면 CPU로 전체를 다시 계산할 수 없다(N=2048에서 이미 1분을 넘는다).
// 그래서 무작위로 고른 원소만 CPU로 직접 구해 대조한다.
// 메시지 형식과 오차 기준은 compare_float과 같다.
static int spot_check(const float* A, const float* B, const float* C,
                      unsigned int N, unsigned int samples, float tol) {
    double sq = 0.0;
    for (size_t k = 0; k < (size_t)N*N; ++k) sq += (double)C[k]*C[k];
    float scale = (float)sqrt(sq/((double)N*N));
    if (scale < 1e-6f) scale = 1e-6f;

    unsigned int s = 12345u;
    for (unsigned int t = 0; t < samples; ++t) {
        s = s*1664525u + 1013904223u;  unsigned int row = (s >> 8) % N;
        s = s*1664525u + 1013904223u;  unsigned int col = (s >> 8) % N;

        float sum = 0.0f;
        for (unsigned int i = 0; i < N; ++i) {
            sum += A[row*N + i]*B[i*N + col];
        }
        float got = C[row*N + col];
        float rel = fabsf(sum - got)/scale;
        if (rel > tol || isnan(got)) {
            printf("  첫 불일치: [%zu]  기대 %.6f  실제 %.6f  (오차/기준크기 %.3e)\n",
                   (size_t)row*N + col, sum, got, rel);
            return 0;
        }
    }
    return 1;
}

int main(int argc, char** argv) {

    unsigned int N        = (argc > 1) ? (unsigned int)atoi(argv[1]) : 4096;
    unsigned int BLOCK_DIM = (argc > 2) ? (unsigned int)atoi(argv[2]) : 16;

    if (BLOCK_DIM != 8 && BLOCK_DIM != 16 && BLOCK_DIM != 32) {
        fprintf(stderr, "blockDim은 8, 16, 32 중 하나여야 한다 (받은 값: %u)\n", BLOCK_DIM);
        return 1;
    }
    if (N == 0 || N % BLOCK_DIM != 0) {
        fprintf(stderr, "N은 blockDim의 배수여야 한다 (N=%u, blockDim=%u)\n", N, BLOCK_DIM);
        return 1;
    }
    if (N > 8192) {
        fprintf(stderr, "N은 8192 이하로 한다 (VRAM 8GB)\n");
        return 1;
    }

    size_t bytes = (size_t)N*N*sizeof(float);
    printf("N = %u, blockDim = %u x %u, 행렬 하나당 %.1f MB\n",
           N, BLOCK_DIM, BLOCK_DIM, bytes/(1024.0*1024.0));

    // 호스트 메모리
    float* A = (float*)malloc(bytes);
    float* B = (float*)malloc(bytes);
    float* C = (float*)malloc(bytes);
    init_matrix(A, N, 1u);
    init_matrix(B, N, 2u);

    // 디바이스 메모리
    float *A_d, *B_d, *C_d;
    CUDA_CHECK(cudaMalloc((void**) &A_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &B_d, bytes));
    CUDA_CHECK(cudaMalloc((void**) &C_d, bytes));
    CUDA_CHECK(cudaMemcpy(A_d, A, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemcpy(B_d, B, bytes, cudaMemcpyHostToDevice));
    CUDA_CHECK(cudaMemset(C_d, 0, bytes));

    dim3 block(BLOCK_DIM, BLOCK_DIM);
    dim3 grid(N/BLOCK_DIM, N/BLOCK_DIM);
    Timer timer;

    // 한 번 예열한 뒤 측정한다 (첫 호출에는 초기화 비용이 섞인다)
    mm_kernel<<<grid, block>>>(A_d, B_d, C_d, N);
    CUDA_CHECK(cudaGetLastError());
    CUDA_CHECK(cudaDeviceSynchronize());
    timer.start();
    mm_kernel<<<grid, block>>>(A_d, B_d, C_d, N);
    float ms = timer.stop();
    CUDA_CHECK(cudaMemcpy(C, C_d, bytes, cudaMemcpyDeviceToHost));

    // 정확성 — N이 작으면 CPU로 전부 다시 계산해 대조하고,
    // 크면 무작위 표본만 대조한다. CPU 행렬곱은 N^3이라 금방 감당이 안 된다.
    int ok;
    if (N <= 1024) {
        float* C_ref = (float*)malloc(bytes);
        mat_mul(A, B, C_ref, N);
        ok = compare_float(C_ref, C, (size_t)N*N, 1e-3f);
        printf("검증: CPU 참조 전체 대조 (%u x %u)\n", N, N);
        free(C_ref);
    } else {
        const unsigned int samples = 4096;
        ok = spot_check(A, B, C, N, samples, 1e-3f);
        printf("검증: CPU 참조 표본 대조 (무작위 %u개 원소)\n", samples);
    }

    double gflop = 2.0*N*N*N/1e9;
    printf("naive : %8.3f ms  (%7.1f GFLOP/s)\n", ms, gflop/(ms/1e3));
    printf("정확성: %s\n", ok ? "PASS" : "FAIL");

    free(A); free(B); free(C);
    CUDA_CHECK(cudaFree(A_d)); CUDA_CHECK(cudaFree(B_d)); CUDA_CHECK(cudaFree(C_d));
    return ok ? 0 : 1;
}
