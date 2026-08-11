// 1주차 도전 과제 — 루프 순서와 캐시
// 같은 행렬곱을 두 가지 루프 순서로 수행하고 시간을 비교한다.
// 두 함수를 나란히 놓고 무엇이 다른지 찾는 것이 목적이다.
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>

// ---------------------------------------------------------------------------
// 순서 1
// ---------------------------------------------------------------------------
void matmul_ijk(const float* A, const float* B, float* C, int N) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            for (int k = 0; k < N; ++k) {
                C[i*N + j] += A[i*N + k]*B[k*N + j];
            }
        }
    }
}

// ---------------------------------------------------------------------------
// 순서 2
// ---------------------------------------------------------------------------
void matmul_ikj(const float* A, const float* B, float* C, int N) {
    for (int i = 0; i < N; ++i) {
        for (int k = 0; k < N; ++k) {
            for (int j = 0; j < N; ++j) {
                C[i*N + j] += A[i*N + k]*B[k*N + j];
            }
        }
    }
}

// ---------------------------------------------------------------------------
// 아래는 측정용 코드다.
// ---------------------------------------------------------------------------

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec*1000.0 + t.tv_nsec/1.0e6;
}

int main(int argc, char** argv) {

    int N = (argc > 1) ? atoi(argv[1]) : 1024;
    if (N < 2 || N > 4096) {
        fprintf(stderr, "N은 2 이상 4096 이하여야 한다 (받은 값: %d)\n", N);
        return 1;
    }

    size_t nn = (size_t)N*N;
    float* A     = (float*)malloc(nn*sizeof(float));
    float* B     = (float*)malloc(nn*sizeof(float));
    float* C_ijk = (float*)malloc(nn*sizeof(float));
    float* C_ikj = (float*)malloc(nn*sizeof(float));
    if (!A || !B || !C_ijk || !C_ikj) { fprintf(stderr, "메모리 부족\n"); return 1; }

    unsigned int s = 1u;
    for (size_t t = 0; t < nn; ++t) {
        s = s*1664525u + 1013904223u;
        A[t] = (float)(s >> 16)/65536.0f - 0.5f;
        s = s*1664525u + 1013904223u;
        B[t] = (float)(s >> 16)/65536.0f - 0.5f;
        C_ijk[t] = 0.0f;
        C_ikj[t] = 0.0f;
    }

    printf("N = %d\n\n", N);

    double t0 = now_ms();
    matmul_ijk(A, B, C_ijk, N);
    double ms_ijk = now_ms() - t0;

    t0 = now_ms();
    matmul_ikj(A, B, C_ikj, N);
    double ms_ikj = now_ms() - t0;

    printf("ijk 순서 : %8.1f ms\n", ms_ijk);
    printf("ikj 순서 : %8.1f ms\n", ms_ikj);
    printf("비율     : %8.2f 배\n", ms_ijk/ms_ikj);

    // 두 결과가 같아야 한다. 같은 연산을 순서만 바꿔 한 것이기 때문이다.
    double max_diff = 0.0;
    for (size_t t = 0; t < nn; ++t) {
        double d = fabs((double)C_ijk[t] - (double)C_ikj[t]);
        if (d > max_diff) max_diff = d;
    }
    printf("\n두 결과의 최대 차이 : %.3e  (%s)\n",
           max_diff, (max_diff < 1e-3) ? "같다" : "다르다");

    free(A); free(B); free(C_ijk); free(C_ikj);
    return 0;
}
