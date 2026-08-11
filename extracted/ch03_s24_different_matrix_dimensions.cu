// 출처: Chapter 03 - Multidimensional Grids and Data.pptx / slide 24
// 제목: Different Matrix Dimensions
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void mm_kernel(float* A, float* B, float* C, unsigned int N)

 __global__ void mm_kernel(float* A, float* B, float* C, unsigned int M, unsigned int N, unsigned int K)
