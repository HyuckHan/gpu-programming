// 출처: Chapter 08 - Stencil.pptx / slide 17
// 제목: Stencil with Shared Memory Tiling Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

#define BLOCK_DIM 8
#define IN_TILE_DIM BLOCK_DIM
#define OUT_TILE_DIM (IN_TILE_DIM - 2)

__global__ void stencil_kernel(float* in, float* out, unsigned int N) {

    int i = blockIdx.z*OUT_TILE_DIM + threadIdx.z - 1;
    int j = blockIdx.y*OUT_TILE_DIM + threadIdx.y - 1;
    int k = blockIdx.x*OUT_TILE_DIM + threadIdx.x - 1;

    __shared__ float in_s[IN_TILE_DIM][IN_TILE_DIM][IN_TILE_DIM];
    if(i >= 0 && i < N && j >= 0 && j < N && k >= 0 && k < N) {
        in_s[threadIdx.z][threadIdx.y][threadIdx.x] = in[i*N*N + j*N + k];
    }
    __syncthreads();

    if(i >= 1 && i < N - 1 && j >= 1 && j < N - 1 && k >= 1 && k < N - 1) {
         if(threadIdx.z >= 1 && threadIdx.z < IN_TILE_DIM - 1 && threadIdx.y >= 1
            && threadIdx.y < IN_TILE_DIM - 1 && threadIdx.x >= 1 && threadIdx.x < IN_TILE_DIM - 1) {
            out[i*N*N + j*N + k] = C0*in_s[threadIdx.z][threadIdx.y][threadIdx.x]
                                 + C1*in_s[threadIdx.z][threadIdx.y][threadIdx.x - 1]
                                 + C2*in_s[threadIdx.z][threadIdx.y][threadIdx.x + 1]
                                 + C3*in_s[threadIdx.z][threadIdx.y - 1][threadIdx.x]
                                 + C4*in_s[threadIdx.z][threadIdx.y + 1][threadIdx.x]
                                 + C5*in_s[threadIdx.z - 1][threadIdx.y][threadIdx.x]
                                 + C6*in_s[threadIdx.z + 1][threadIdx.y][threadIdx.x];
        }
    }

}
