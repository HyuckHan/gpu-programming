// 출처: Chapter 02 - Heterogeneous Data Parallel Computing.pptx / slide 18
// 제목: Parallel Vector Addition in CUDA
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void vecadd_kernel(float* x, float* y, float* z, int N) {
    int i = blockDim.x*blockIdx.x + threadIdx.x;
    z[i] = x[i] + y[i];
}
