// 출처: Chapter 10 - Reduction.pptx / slide 20
// 제목: Reduction Code with Thread Coarsening
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

unsigned int segment = COARSE_FACTOR*2*blockDim.x*blockIdx.x;
unsigned int i = segment + threadIdx.x;

// Load data to shared memory
__shared__ float input_s[BLOCK_DIM];
float threadSum = 0.0f;
for(unsigned int c = 0; c < COARSE_FACTOR*2; ++c) {
    threadSum += input[i + c*BLOCK_DIM];
}
input_s[threadIdx.x] = threadSum;

__syncthreads();

// Reduction tree in shared memory
for(unsigned int stride = BLOCK_DIM/2; stride > 0; stride /= 2) {
    if(threadIdx.x < stride) {
        input_s[threadIdx.x] += input_s[threadIdx.x + stride];
    }
    __syncthreads();
}
