// 출처: Chapter 04 - Compute Architecture and Scheduling.pptx / slide 21
// 제목: Querying Available Resources
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

프로그래머는 디바이스 속성(Device Properties)을 조회하여 GPU가 제공하는 하드웨어 자원을 확인할 수 있다.
이를 통해 최대 스레드 수, 최대 블록 수, 공유 메모리 크기 등의 정보를 확인할 수 있다.

cudaError_t cudaGetDeviceProperties(cudaDeviceProp* prop,                                              int  device)
Example:
int devID = 0;
cudaDeviceProp devProp;
cudaGetDeviceProperties(&devProp, devID);
int maxThreadsPerBlock = devProp.maxThreadsPerBlock;
int maxThreadsPerMultiProcessor =               devProp.maxThreadsPerMultiProcessor;
