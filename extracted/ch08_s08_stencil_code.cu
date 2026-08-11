// 출처: Chapter 08 - Stencil.pptx / slide 8
// 제목: Stencil Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

#define BLOCK_DIM  8

__global__ void stencil_kernel(float* in, float* out, unsigned int N) {
    unsigned int i = blockIdx.z*blockDim.z + threadIdx.z;
    unsigned int j = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int k = blockIdx.x*blockDim.x + threadIdx.x;
    if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1&& k >= 1 && k < N - 1) {
        out[i*N*N + j*N + k] = C0*in[i*N*N + j*N + k]
                             + C1*in[i*N*N + j*N + (k - 1)]
                             + C2*in[i*N*N + j*N + (k + 1)]
                             + C3*in[i*N*N + (j - 1)*N + k]
                             + C4*in[i*N*N + (j + 1)*N + k]
                             + C5*in[(i - 1)*N*N + j*N + k]
                             + C6*in[(i + 1)*N*N + j*N + k];
    }
}
