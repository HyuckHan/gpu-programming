// 출처: Chapter 11 - Prefix Sum (Scan) - Part 1.pptx / slide 17
// 제목: Exclusive Scan
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

    unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;

    __shared__ float buffer1_s[BLOCK_DIM];
    __shared__ float buffer2_s[BLOCK_DIM];
    float* inBuffer_s = buffer1_s;
    float* outBuffer_s = buffer2_s;
    if(threadIdx.x == 0) {
        inBuffer_s[threadIdx.x] = 0.0f;
    } else {
        inBuffer_s[threadIdx.x] = input[i - 1];
    }
    __syncthreads();

    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        if(threadIdx.x >= stride) {
            outBuffer_s[threadIdx.x] =
                    inBuffer_s[threadIdx.x] + inBuffer_s[threadIdx.x - stride];
        } else {
            outBuffer_s[threadIdx.x] = inBuffer_s[threadIdx.x];
        }
        __syncthreads();
        float* tmp = inBuffer_s;
        inBuffer_s = outBuffer_s;
        outBuffer_s = tmp;
    }

    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = inBuffer_s[threadIdx.x] + input[i];
    }

    output[i] = inBuffer_s[threadIdx.x];
