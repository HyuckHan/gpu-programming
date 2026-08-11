// 출처: Chapter 11 - Prefix Sum (Scan) - Part 1.pptx / slide 10
// 제목: Kogge-Stone Parallel (Inclusive) Scan Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.


    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    output[i] = input[i];

    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        float v;
        if(threadIdx.x >= stride) {
            v = output[i - stride];
        }
        __syncthreads();
        if(threadIdx.x >= stride) {
            output[i] += v;
        }
        __syncthreads();
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = output[i];
    }
