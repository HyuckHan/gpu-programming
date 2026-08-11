// 출처: Chapter 03 - Multidimensional Grids and Data.pptx / slide 14
// 제목: Boundary Conditions
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

__global__ void rgb2gray_kernel(unsigned char* red, unsigned char* green, unsigned char* blue, 
                                unsigned char* gray, unsigned int width, unsigned int height) {

    unsigned int row = blockIdx.y*blockDim.y + threadIdx.y;
    unsigned int col = blockIdx.x*blockDim.x + threadIdx.x;

    // Convert the pixel
    if (row < height && col < width) {
        gray[row*width + col] = red[row*width + col]*3/10 
                + green[row*width + col]*6/10 + blue[row*width + col]/10;
    }
}
