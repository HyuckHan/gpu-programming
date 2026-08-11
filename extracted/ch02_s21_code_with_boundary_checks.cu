// 출처: Chapter 02 - Heterogeneous Data Parallel Computing.pptx / slide 21
// 제목: Code with Boundary Checks
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void vecadd_kernel(float* x, float* y, float* z, int N) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;

    if(i < N) {
        z[i] = x[i] + y[i];
    }
}
