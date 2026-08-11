// 출처: Chapter 10 - Reduction.pptx / slide 4
// 제목: Parallel Reduction with Atomics
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
if(i < N) {
    atomicAdd(sum, input[i]);
}
