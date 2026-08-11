// 출처: Chapter 10 - Reduction.pptx / slide 9
// 제목: Reduction Code
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

unsigned int segment = 2*blockDim.x*blockIdx.x;
unsigned int i = segment + 2*threadIdx.x;
for(unsigned int stride = 1; stride <= BLOCK_DIM; stride *= 2) {
    if(threadIdx.x%stride == 0) {
        input[i] += input[i + stride];
    }
    __syncthreads();
}
