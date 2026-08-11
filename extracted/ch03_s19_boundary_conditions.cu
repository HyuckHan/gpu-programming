// 출처: Chapter 03 - Multidimensional Grids and Data.pptx / slide 19
// 제목: Boundary Conditions
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void blur_kernel(unsigned char* image, unsigned char* blurred, 
                            unsigned int width, unsigned int height) {

    int outRow = blockIdx.y*blockDim.y + threadIdx.y;
    int outCol = blockIdx.x*blockDim.x + threadIdx.x;

    if (outRow < height && outCol < width) {

        unsigned int average = 0;
        unsigned int count = 0;
        for(int inRow = outRow - BLUR_SIZE; inRow < outRow + BLUR_SIZE + 1; ++inRow) {
            for(int inCol = outCol - BLUR_SIZE; inCol < outCol + BLUR_SIZE + 1; ++inCol) {
                if(inRow >= 0 && inRow < height && inCol >= 0 && inCol < width) {
                    average += image[inRow*width + inCol];
                    count++;
                }
            }
        }
        blurred[outRow*width + outCol] = (unsigned char)(average/count);

    }

}
