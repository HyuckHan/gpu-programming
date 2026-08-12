#include <stdio.h>
#include <math.h>

int main(void) {
    float v[] = {1.0f, 1024.0f, 8388608.0f, 16777216.0f, 33554432.0f};

    printf("값과 바로 다음 float\n");
    for (int k = 0; k < 5; ++k) {
        float next = nextafterf(v[k], 1e30f);
        printf("  %12.1f  ->  %12.1f    차이 %g\n", v[k], next, (double)(next - v[k]));
    }

    float s = 16777216.0f;
    printf("\n16777216 에 더해 보기\n");
    printf("  + 0.5 = %.1f\n", s + 0.5f);
    printf("  + 1.0 = %.1f\n", s + 1.0f);
    printf("  + 2.0 = %.1f\n", s + 2.0f);

    printf("\n0.5 를 67108864 번 더하기\n");
    float f = 0.0f;
    double d = 0.0;
    for (long i = 1; i <= 67108864L; ++i) {
        f += 0.5f;
        d += 0.5;
        if (i % 8388608L == 0) {
            printf("  %9ld회   float %14.1f   double %14.1f\n", i, f, d);
        }
    }

    printf("\n같은 총합을 256 씩 131072 번 더하기\n");
    float g = 0.0f;
    for (long b = 0; b < 131072L; ++b) g += 256.0f;
    printf("  float %14.1f   참값 %14.1f\n", g, 131072.0*256.0);

    return 0;
}
