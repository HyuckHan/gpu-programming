// 출처: Chapter 11 - Prefix Sum (Scan) - Part 2.pptx / slide 21
// 제목: Kogge-Stone Parallel (Inclusive) Scan with Thread Coarsening Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

    unsigned int segment = COARSE_FACTOR*blockIdx.x*blockDim.x;

    // Load data to shared memory
    __shared__ float buffer_s[COARSE_FACTOR*BLOCK_DIM];
    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        buffer_s[c*BLOCK_DIM + threadIdx.x] = input[segment + c*BLOCK_DIM + threadIdx.x];
    }
    __syncthreads();

    // Scan thread subsegment
    unsigned int threadSegment = threadIdx.x*COARSE_FACTOR;
    for(unsigned int c = 1; c < COARSE_FACTOR; ++c) {
        buffer_s[threadSegment + c] += buffer_s[threadSegment + c - 1];
    }

    // Allocate and initialize double buffers for partial sums
    __shared__ float buffer1_s[BLOCK_DIM];
    __shared__ float buffer2_s[BLOCK_DIM];
    float* inBuffer_s = buffer1_s;
    float* outBuffer_s = buffer2_s;
    unsigned int partialSumIdx = threadSegment + COARSE_FACTOR - 1;
    inBuffer_s[threadIdx.x] = buffer_s[partialSumIdx];
    __syncthreads();

    // Parallel scan of partial sums
    for(unsigned int stride = 1; stride <= BLOCK_DIM/2; stride *= 2) {
        if(threadIdx.x >= stride) {
            outBuffer_s[threadIdx.x] = inBuffer_s[threadIdx.x] + inBuffer_s[threadIdx.x - stride];
        } else {
            outBuffer_s[threadIdx.x] = inBuffer_s[threadIdx.x];
        }
        __syncthreads();
        float* tmp = inBuffer_s;
        inBuffer_s = outBuffer_s;
        outBuffer_s = tmp;
    }

    ...
