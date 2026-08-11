// GPU 프로그래밍 실습 공용 하니스 — 모든 랩이 이 파일 하나를 공유한다.
// 외부 헤더 의존 없음. 표준 라이브러리와 CUDA 런타임만 쓴다.
#ifndef COMMON_CUH
#define COMMON_CUH

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// CUDA API 호출을 감싸면 실패 지점(파일:행)을 찍고 즉시 종료한다.
// 사용법:  CUDA_CHECK(cudaMalloc(&A_d, bytes));
#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t err_ = (call);                                             \
        if (err_ != cudaSuccess) {                                             \
            fprintf(stderr, "[CUDA 오류] %s:%d  %s\n",                         \
                    __FILE__, __LINE__, cudaGetErrorString(err_));             \
            exit(EXIT_FAILURE);                                                \
        }                                                                      \
    } while (0)

// cudaEvent 기반 타이머. start() 후 stop()이 경과 시간을 ms로 돌려준다.
// stop()이 내부에서 동기화하므로 커널 뒤에 따로 cudaDeviceSynchronize를 부를 필요는 없다.
struct Timer {
    cudaEvent_t beg, end;
    Timer()  { CUDA_CHECK(cudaEventCreate(&beg)); CUDA_CHECK(cudaEventCreate(&end)); }
    ~Timer() { cudaEventDestroy(beg); cudaEventDestroy(end); }
    void start() { CUDA_CHECK(cudaEventRecord(beg)); }
    float stop() {
        float ms;
        CUDA_CHECK(cudaEventRecord(end));
        CUDA_CHECK(cudaEventSynchronize(end));
        CUDA_CHECK(cudaEventElapsedTime(&ms, beg, end));
        return ms;
    }
};

// N x N 행렬을 -0.5 ~ 0.5 난수로 채운다.
// 시드가 같으면 어느 PC에서 몇 번을 돌려도 같은 값이 나온다(재현 가능).
static inline void init_matrix(float* M, unsigned int N, unsigned int seed) {
    unsigned int s = seed;
    for (unsigned int i = 0; i < N*N; ++i) {
        s = s*1664525u + 1013904223u;                     // 선형 합동 생성기
        M[i] = (float)(s >> 16)/65536.0f - 0.5f;
    }
}

// CPU 참조 행렬곱. 변수명은 슬라이드의 mm_kernel과 같다.
// O(N^3)이라 N이 커지면 매우 느리다. 작은 N에서만 쓸 것.
static inline void mm_cpu(const float* A, const float* B, float* C, unsigned int N) {
    for (unsigned int row = 0; row < N; ++row) {
        for (unsigned int col = 0; col < N; ++col) {
            float sum = 0.0f;
            for (unsigned int i = 0; i < N; ++i) {
                sum += A[row*N + i]*B[i*N + col];
            }
            C[row*N + col] = sum;
        }
    }
}

// ref와 test를 상대오차 tol 이내에서 비교한다.
// 같으면 1, 다르면 첫 불일치 위치를 출력하고 0을 반환한다.
//
// 오차를 원소값 자기 자신으로 나누면 안 된다. 행렬곱 결과에는 덧셈이 서로
// 상쇄되어 0에 가까워진 원소가 섞여 있고, 그런 원소는 절대오차가 1e-7 수준이어도
// 상대오차가 커 보인다. 그래서 행렬 전체의 대표 크기(RMS)를 기준으로 나눈다.
static inline int compare_matrices(const float* ref, const float* test,
                                   unsigned int N, float tol) {
    double sq = 0.0;   // 원소가 수천만 개라 float로 누적하면 합 자체가 부정확해진다.
    for (unsigned int i = 0; i < N*N; ++i) sq += (double)ref[i]*ref[i];
    float scale = (float)sqrt(sq/((double)N*N));
    if (scale < 1e-6f) scale = 1e-6f;

    for (unsigned int i = 0; i < N*N; ++i) {
        float diff = fabsf(ref[i] - test[i]);
        float rel  = diff/scale;
        if (rel > tol || isnan(test[i])) {
            printf("  첫 불일치: C[%u][%u]  기대 %.6f  실제 %.6f  (오차/기준크기 %.3e)\n",
                   i/N, i%N, ref[i], test[i], rel);
            return 0;
        }
    }
    return 1;
}

#endif // COMMON_CUH
