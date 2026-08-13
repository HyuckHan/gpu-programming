// 1주차 — C 워밍업
// CUDA를 쓰지 않는다. gcc만 있으면 된다.
//
// 모든 행렬은 1차원 배열 하나로 표현한다.
// row행 col열의 원소는  A[row*N + col]  이다. 이 감각이 이 실습의 전부다.
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <time.h>

// ---------------------------------------------------------------------------
// 1. 행렬 덧셈 — 완성되어 있다. 아래 두 함수의 본보기다.
// ---------------------------------------------------------------------------
void mat_add(const float* A, const float* B, float* C, int N) {
    for (int row = 0; row < N; ++row) {
        for (int col = 0; col < N; ++col) {
            C[row*N + col] = A[row*N + col] + B[row*N + col];
        }
    }
}

// ---------------------------------------------------------------------------
// 2. 행렬 곱셈 — 여기를 채운다
//
// C의 row행 col열 원소는 A의 row행과 B의 col열을 짝지어 곱한 뒤 모두 더한 값이다.
// ---------------------------------------------------------------------------
void mat_mul(const float* A, const float* B, float* C, int N) {

    for (int row = 0; row < N; ++row) {
        for (int col = 0; col < N; ++col) {
            float sum = 0.0f;
            for (int i = 0; i < N; ++i) {
                sum += A[row*N + i] * B[i*N + col];
            }
            C[row*N + col] = sum;
        }
    }

}

// ---------------------------------------------------------------------------
// 3. 전치 — 여기를 채운다
//
// A는 rows행 cols열이고, B는 cols행 rows열이 된다. 모양이 바뀐다는 점이 중요하다.
// ---------------------------------------------------------------------------
void mat_transpose(const float* A, float* B, int rows, int cols) {

    for (int row = 0; row < rows; ++row) {
        for (int col = 0; col < cols; ++col) {
            B[col*rows + row] = A[row*cols + col];
        }
    }

}

// ---------------------------------------------------------------------------
// 아래는 채점용 코드다. 고칠 필요 없다.
// ---------------------------------------------------------------------------

// 기대값과 비교해서 같으면 1, 다르면 0을 반환한다.
// 불일치 내용은 곧바로 찍지 않고 모아 둔다. PASS/FAIL 줄이 먼저 나와야 읽기 좋다.
static char g_msg[512];

static void msg_reset(void) { g_msg[0] = '\0'; }
static void msg_flush(void) { if (g_msg[0]) fputs(g_msg, stdout); }

static int check(const float* got, const float* expect, int n, const char* tag) {
    for (int i = 0; i < n; ++i) {
        if (fabsf(got[i] - expect[i]) > 1e-4f) {
            char line[256];
            snprintf(line, sizeof line, "    %s첫 불일치: [%d]  기대 %.6f  실제 %.6f\n",
                     tag, i, expect[i], got[i]);
            strncat(g_msg, line, sizeof(g_msg) - strlen(g_msg) - 1);
            return 0;
        }
    }
    return 1;
}

// N=4. 손으로 계산해서 확인할 수 있는 크기다.
static int test_mat_add(void) {
    const int N = 4;
    float A[16], B[16], C[16], expect[16];
    for (int i = 0; i < N*N; ++i) {
        A[i] = (float)i;              // 0, 1, 2, ... 15
        B[i] = (float)(100 + i);      // 100, 101, ... 115
        expect[i] = (float)(100 + 2*i);
        C[i] = -1.0f;
    }
    mat_add(A, B, C, N);
    return check(C, expect, N*N, "");
}

// A는 행마다 같은 값(row+1), B는 열마다 같은 값(col+1)으로 채운다.
// 그러면 C[row][col] = 4*(row+1)*(col+1) 이 되어 손으로 검산할 수 있다.
// 첨자를 뒤집어 쓰면 값이 전혀 달라지므로 그런 실수도 걸린다.
static int test_mat_mul(void) {
    const int N = 4;
    float A[16], B[16], C[16], expect[16];
    for (int row = 0; row < N; ++row) {
        for (int col = 0; col < N; ++col) {
            A[row*N + col] = (float)(row + 1);
            B[row*N + col] = (float)(col + 1);
            expect[row*N + col] = (float)(N*(row + 1)*(col + 1));
            C[row*N + col] = -1.0f;
        }
    }
    mat_mul(A, B, C, N);
    return check(C, expect, N*N, "");
}

// 정사각과 비정사각을 모두 본다.
// 정사각만 보면 rows와 cols를 바꿔 써도 통과해 버린다.
static int test_mat_transpose(void) {
    int ok = 1;

    // (1) 4x4 정사각
    {
        const int n = 4;
        float A[16], B[16], expect[16];
        for (int row = 0; row < n; ++row)
            for (int col = 0; col < n; ++col) {
                A[row*n + col] = (float)(row*n + col);
                expect[col*n + row] = (float)(row*n + col);
                B[row*n + col] = -1.0f;
            }
        mat_transpose(A, B, n, n);
        if (!check(B, expect, n*n, "[4x4 정사각] ")) ok = 0;
    }

    // (2) 3x2 비정사각 — 결과는 2x3이 된다
    //     A = 1 2      B = 1 3 5
    //         3 4          2 4 6
    //         5 6
    {
        float A[6] = {1, 2, 3, 4, 5, 6};
        float expect[6] = {1, 3, 5, 2, 4, 6};
        float B[6] = {-1, -1, -1, -1, -1, -1};
        mat_transpose(A, B, 3, 2);
        if (!check(B, expect, 6, "[3x2 비정사각] ")) ok = 0;
    }

    return ok;
}

static double now_ms(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec*1000.0 + t.tv_nsec/1.0e6;
}

int main(int argc, char** argv) {

    int N = (argc > 1) ? atoi(argv[1]) : 512;
    if (N < 2 || N > 4096) {
        fprintf(stderr, "N은 2 이상 4096 이하여야 한다 (받은 값: %d)\n", N);
        return 1;
    }

    printf("=== 1. 정확성 확인 (손으로 계산할 수 있는 크기) ===\n");

    msg_reset();
    printf("mat_add       : %s\n", test_mat_add() ? "PASS" : "FAIL");
    msg_flush();

    msg_reset();
    printf("mat_mul       : %s\n", test_mat_mul() ? "PASS" : "FAIL");
    msg_flush();

    msg_reset();
    printf("mat_transpose : %s\n", test_mat_transpose() ? "PASS" : "FAIL");
    msg_flush();

    // 큰 크기에서는 손계산이 안 되므로, 반드시 성립해야 하는 성질로 확인한다.
    printf("\n=== 2. 큰 크기에서 확인 (N=%d) ===\n", N);

    size_t nn = (size_t)N*N;
    float* A    = (float*)malloc(nn*sizeof(float));
    float* Zero = (float*)malloc(nn*sizeof(float));
    float* Ident= (float*)malloc(nn*sizeof(float));
    float* C    = (float*)malloc(nn*sizeof(float));
    if (!A || !Zero || !Ident || !C) { fprintf(stderr, "메모리 부족\n"); return 1; }

    unsigned int s = 1u;
    for (int row = 0; row < N; ++row) {
        for (int col = 0; col < N; ++col) {
            s = s*1664525u + 1013904223u;
            A[row*N + col]     = (float)(s >> 16)/65536.0f;
            Zero[row*N + col]  = 0.0f;
            Ident[row*N + col] = (row == col) ? 1.0f : 0.0f;
        }
    }

    // 매번 결과 버퍼를 못 쓸 값으로 덮어 둔다. 그러지 않으면 앞 함수가 남긴
    // 올바른 값이 그대로 남아, 아무것도 하지 않는 함수가 통과해 버린다.
    for (size_t k = 0; k < nn; ++k) C[k] = -1.0f;
    double t0 = now_ms();
    mat_add(A, Zero, C, N);
    double t_add = now_ms() - t0;
    msg_reset();
    printf("mat_add       : %s   (A + 0 = A,  %.1f ms)\n",
           check(C, A, (int)nn, "") ? "PASS" : "FAIL", t_add);
    msg_flush();

    for (size_t k = 0; k < nn; ++k) C[k] = -1.0f;
    t0 = now_ms();
    mat_mul(A, Ident, C, N);
    double t_mul = now_ms() - t0;
    msg_reset();
    printf("mat_mul       : %s   (A x I = A,  %.1f ms)\n",
           check(C, A, (int)nn, "") ? "PASS" : "FAIL", t_mul);
    msg_flush();

    // rows != cols 로 두 번 전치하면 원래 행렬로 돌아와야 한다.
    int rows = N, cols = N/2;
    float* T  = (float*)malloc((size_t)rows*cols*sizeof(float));
    float* TT = (float*)malloc((size_t)rows*cols*sizeof(float));
    if (!T || !TT) { fprintf(stderr, "메모리 부족\n"); return 1; }

    for (size_t k = 0; k < (size_t)rows*cols; ++k) { T[k] = -1.0f; TT[k] = -1.0f; }
    t0 = now_ms();
    mat_transpose(A, T, rows, cols);      // rows x cols  ->  cols x rows
    mat_transpose(T, TT, cols, rows);     // cols x rows  ->  rows x cols
    double t_tr = now_ms() - t0;
    msg_reset();
    printf("mat_transpose : %s   (%dx%d 두 번 전치 = 원래,  %.1f ms)\n",
           check(TT, A, rows*cols, "") ? "PASS" : "FAIL", rows, cols, t_tr);
    msg_flush();

    printf("\n못 채운 함수가 있어도 괜찮다. 이 실습은 채점하지 않는다.\n");

    free(A); free(Zero); free(Ident); free(C); free(T); free(TT);
    return 0;
}
