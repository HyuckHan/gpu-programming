// 출처: Chapter 11 - Prefix Sum (Scan) - Part 2.pptx / slide 22
// 제목: Kogge-Stone Parallel (Inclusive) Scan with Thread Coarsening Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.


    ...

    // Add previous thread's partial sums
    if(threadIdx.x > 0) {
        float prevPartialSum = inBuffer_s[threadIdx.x - 1];
        for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
            buffer_s[threadSegment + c] += prevPartialSum;
        }
    }
    __syncthreads();

    // Save block's partial sum
    if(threadIdx.x == BLOCK_DIM - 1) {
        partialSums[blockIdx.x] = buffer_s[COARSE_FACTOR*BLOCK_DIM - 1];
    }

    // Write output
    for(unsigned int c = 0; c < COARSE_FACTOR; ++c) {
        output[segment + c*BLOCK_DIM + threadIdx.x] = buffer_s[c*BLOCK_DIM + threadIdx.x];
    }
