// 출처: Chapter 02 - Heterogeneous Data Parallel Computing.pptx / slide 7
// 제목: CUDA Memory Management API
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

Copying memory:

cudaError_t cudaMemcpy(void *dst, const void *src,              size_t count, enum cudaMemcpyKind kind)
dst: Destination memory address
src: Source memory address
count: Size in bytes to copy
kind: Type of transfer
cudaMemcpyHostToHost
cudaMemcpyHostToDevice
cudaMemcpyDeviceToHost
cudaMemcpyDeviceToDevice
