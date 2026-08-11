// 1주차 — 환경 확인
// nvcc가 동작하는지, GPU가 보이는지, 커널이 실제로 도는지만 확인한다.
// 문제가 생겨도 여기서 죽지 않는다. 원인을 알려주고 정상 종료한다.
#include <stdio.h>

__global__ void hello_kernel(void) {
    if (threadIdx.x < 4) {
        printf("  커널 안에서 인사합니다. threadIdx.x = %d\n", threadIdx.x);
    }
}

int main(void) {

    printf("=== 1단계: GPU가 보이는지 ===\n");

    int count = 0;
    cudaError_t err = cudaGetDeviceCount(&count);

    if (err != cudaSuccess) {
        printf("GPU를 찾지 못했다: %s\n\n", cudaGetErrorString(err));
        printf("확인할 것\n");
        printf("  1. nvidia-smi 가 동작하는가 (안 되면 드라이버 문제다)\n");
        printf("  2. 실습실 PC가 맞는가 (원격 접속이면 GPU가 없는 서버일 수 있다)\n");
        printf("  3. 위 두 가지가 정상인데도 안 되면 손을 들어라\n");
        return 0;                       // 여기서 죽지 않는다
    }
    if (count == 0) {
        printf("CUDA를 지원하는 GPU가 0개다.\n\n");
        printf("확인할 것\n");
        printf("  1. nvidia-smi 로 GPU가 목록에 나오는가\n");
        printf("  2. 다른 사람이 GPU를 독점하고 있지는 않은가\n");
        return 0;
    }

    printf("GPU %d개를 찾았다.\n\n", count);

    for (int d = 0; d < count; ++d) {
        cudaDeviceProp prop;
        if (cudaGetDeviceProperties(&prop, d) != cudaSuccess) {
            printf("  [%d] 정보를 읽지 못했다\n", d);
            continue;
        }
        printf("  [%d] %s  (compute capability %d.%d)\n",
               d, prop.name, prop.major, prop.minor);
    }

    printf("\n=== 2단계: 커널이 실제로 도는지 ===\n");

    hello_kernel<<<1, 32>>>();

    err = cudaDeviceSynchronize();
    if (err != cudaSuccess) {
        printf("커널이 실행되지 않았다: %s\n\n", cudaGetErrorString(err));
        printf("확인할 것\n");
        printf("  1. 빌드할 때 -arch=native 가 붙었는가 (Makefile이 붙여 준다)\n");
        printf("  2. 드라이버가 CUDA 툴킷보다 오래됐을 수 있다. 손을 들어라\n");
        return 0;
    }

    printf("\n여기까지 나왔으면 1주차 필수 목표는 끝났다.\n");
    return 0;
}
