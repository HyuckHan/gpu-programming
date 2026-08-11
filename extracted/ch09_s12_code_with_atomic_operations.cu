// 출처: Chapter 09 - Parallel Histogram.pptx / slide 12
// 제목: Code with Atomic Operations
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

unsigned int i = blockIdx.x*blockDim.x + threadIdx.x;
if(i < width*height) {
    unsigned char b = image[i];
    ++bins[b];
}
