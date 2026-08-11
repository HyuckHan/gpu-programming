// 출처: Chapter 11 - Prefix Sum (Scan) - Part 2.pptx / slide 13
// 제목: Brent Kung Inclusive Scan Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void scan_kernel(float* input, float* output, float* partialSums, unsigned int N) {

    unsigned int segment = 2*blockIdx.x*blockDim.x;

    __shared__ float buffer_s[2*BLOCK_DIM];
    buffer_s[threadIdx.x] = input[segment + threadIdx.x];
    buffer_s[threadIdx.x + BLOCK_DIM] = input[segment + threadIdx.x + BLOCK_DIM];
    __syncthreads();

    // First tree
    for(unsigned int stride = 1; stride <= BLOCK_DIM; stride *= 2) {
        unsigned int i = (threadIdx.x + 1)*2*stride - 1;
        if(i < 2*BLOCK_DIM) {
            buffer_s[i] += buffer_s[i - stride];
        }
        __syncthreads();
    }

    // Second tree
    for(unsigned int stride = BLOCK_DIM/2; stride >= 1; stride /= 2) {
        unsigned int i = (threadIdx.x + 1)*2*stride - 1;
        if(i + stride < 2*BLOCK_DIM) {
            buffer_s[i + stride] += buffer_s[i];
        }
        __syncthreads();
    }

    // Store partial sum
    if(threadIdx.x == 0) {
        partialSums[blockIdx.x] = buffer_s[2*BLOCK_DIM - 1];
    }

    // Store output
    output[segment + threadIdx.x] = buffer_s[threadIdx.x];
    output[segment + threadIdx.x + BLOCK_DIM] = buffer_s[threadIdx.x + BLOCK_DIM];

}
