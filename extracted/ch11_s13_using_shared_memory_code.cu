// 출처: Chapter 11 - Prefix Sum (Scan) - Part 1.pptx / slide 13
// 제목: Using Shared Memory Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    __shared__ float buffer_s[BLOCK_DIM];
    buffer_s[threadIdx.x] = input[i];
    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        float v;
        if(threadIdx.x >= stride) {
            v = buffer_s[threadIdx.x - stride];
        }
        __syncthreads();
        if(threadIdx.x >= stride) {
            buffer_s[threadIdx.x] += v;
        }
        __syncthreads();
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = buffer_s[threadIdx.x];
    }

    output[i] = buffer_s[threadIdx.x];
