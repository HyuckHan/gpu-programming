// GPU 프로그래밍 실습 공용 하니스 — 모든 랩이 이 파일 하나를 공유한다.
// 여기에는 랩 공통 인프라만 둔다. CPU 참조 구현, 데이터 생성, 인자 파싱은
// 랩마다 자료형과 문제 구조가 달라서 각 랩의 .cu 안에 둔다.
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

// ---------------------------------------------------------------------------
// 비교 헬퍼 — 아래 두 함수는 같은 모양의 메시지를 찍는다.
// 랩이 바뀌어도 학생이 보는 형식은 동일하다:
//
//     첫 불일치: [12345]  기대 2.769316  실제 0.000000  (오차/기준크기 1.470e+00)
//     첫 불일치: [12345]  기대 200  실제 187
//
// 위치는 원소 개수 기준의 1차원 인덱스다. 2차원 자료라면 행 = i/N, 열 = i%N.
// 두 함수 모두 a가 기대값(참조), b가 실제값(검사 대상)이고,
// 같으면 1, 다르면 첫 불일치를 출력하고 0을 반환한다.
// ---------------------------------------------------------------------------

// float 배열을 상대오차 tol 이내에서 비교한다.
static inline int compare_float(const float* a, const float* b, size_t n, float tol) {
    // 오차를 원소값 자기 자신으로 나누면 안 된다. 덧셈이 서로 상쇄되어 0에
    // 가까워진 원소는 절대오차가 1e-7 수준이어도 상대오차가 커 보인다.
    // 그래서 배열 전체의 대표 크기(RMS)를 기준으로 나눈다.
    double sq = 0.0;   // 원소가 수천만 개라 float로 누적하면 합 자체가 부정확해진다.
    for (size_t i = 0; i < n; ++i) sq += (double)a[i]*a[i];
    float scale = (float)sqrt(sq/(double)n);
    if (scale < 1e-6f) scale = 1e-6f;

    for (size_t i = 0; i < n; ++i) {
        float rel = fabsf(a[i] - b[i])/scale;
        if (rel > tol || isnan(b[i])) {
            printf("  첫 불일치: [%zu]  기대 %.6f  실제 %.6f  (오차/기준크기 %.3e)\n",
                   i, a[i], b[i], rel);
            return 0;
        }
    }
    return 1;
}

// unsigned char 배열을 정확일치로 비교한다.
// 정수 연산 커널(blur, histogram)은 허용오차를 두지 않는다.
static inline int compare_bytes(const unsigned char* a, const unsigned char* b, size_t n) {
    for (size_t i = 0; i < n; ++i) {
        if (a[i] != b[i]) {
            printf("  첫 불일치: [%zu]  기대 %u  실제 %u\n", i, a[i], b[i]);
            return 0;
        }
    }
    return 1;
}

#endif // COMMON_CUH
