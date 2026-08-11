// 출처: Chapter 06 - Performance Considerations.pptx / slide 22
// 제목: Example: Tiled Matrix-Matrix Multiplication
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void mm_tiled_coarse_kernel(float* A, float* B, float* C, unsigned int M,
                                                     unsigned int N, unsigned int K) {
    __shared__ float A_s[TILE_DIM][TILE_DIM];
    __shared__ float B_s[TILE_DIM][TILE_DIM];
    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int colStart = blockIdx.x*blockDim.x*COARSE_FACTOR + threadIdx.x;
    float sum[COARSE_FACTOR];
    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        sum[c] = 0.0f;
    }
    for(unsigned int tile = 0; tile < N/TILE_DIM; ++tile) {
        // Load A tile
        A_s[threadIdx.y][threadIdx.x] = A[row*N + tile*TILE_DIM + threadIdx.x];
        for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
            unsigned int col = colStart + c*TILE_DIM;
            // Load B tile
            B_s[threadIdx.y][threadIdx.x] = B[(tile*TILE_DIM + threadIdx.y)*N + col];
            __syncthreads();
            // Compute with tile
            for(unsigned int i = 0; i < TILE_DIM; ++i) {
                sum[c] += A_s[threadIdx.y][i]*B_s[i][threadIdx.x];
            }
            __syncthreads();
        }
    }
    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        unsigned int col = colStart + c*TILE_DIM;
        C[row*N + col] = sum[c];
    }
}
