// 출처: Chapter 03 - Multidimensional Grids and Data.pptx / slide 22
// 제목: Example: Matrix-Matrix Multiplication
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void mm_kernel(float* A, float* B, float* C, unsigned int N) {

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int col = blockIdx.x*blockDim.x + threadIdx.x;

    float sum = 0.0f;
    for(unsigned int i = 0; i < N; ++i) {
        sum += A[row*N + i]*B[i*N + col];
    }
    C[row*N + col] = sum;

}
