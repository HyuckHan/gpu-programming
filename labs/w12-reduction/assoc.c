#include <stdio.h>

int main(void) {
    float big = 16777216.0f;
    printf("big                 = %.1f\n", big);
    printf("(big + 1.0f) + 1.0f = %.1f\n", (big + 1.0f) + 1.0f);
    printf("big + (1.0f + 1.0f) = %.1f\n", big + (1.0f + 1.0f));
    return 0;
}
