// 출처: Chapter 02 - Heterogeneous Data Parallel Computing.pptx / slide 13
// 제목: Implementing a Kernel
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

커널은 C/C++ 함수와 거의 동일한 형태로 작성된다. 

함수 앞에 __global__을 붙여 GPU에서 실행되는 커널임을 지정한다. 

threadIdx, blockIdx, blockDim과 같은 CUDA의 내장 변수를 사용하여 각 스레드를 식별한다.
