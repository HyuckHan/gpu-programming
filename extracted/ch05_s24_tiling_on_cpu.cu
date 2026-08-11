// 출처: Chapter 05 - Memory Architecture and Data Locality.pptx / slide 24
// 제목: Tiling on CPU
// 주의: 커널 본체 조각이다. 시그니처와 호스트 코드는 직접 붙여야 한다.

    for(unsigned int rowTile = 0; rowTile < N/TILE_DIM; ++rowTile) {
        for(unsigned int colTile = 0; colTile < N/TILE_DIM; ++colTile) {
            for(unsigned int iTile = 0; iTile < N/TILE_DIM; ++iTile) {
                for (unsigned int row = rowTile*TILE_DIM; row < (rowTile + 1)*TILE_DIM; ++row) {
                    for (unsigned int col = colTile*TILE_DIM; col < (colTile + 1)*TILE_DIM; ++col) {
                        float sum = 0.0f;
                        for(unsigned int i = iTile*TILE_DIM; i < (iTile + 1)*TILE_DIM; ++i) {
                            sum += A[row*N + i]*B[i*N + col];
                        }
                        if(iTile == 0) {
                            C[row*N + col] = sum;
                        } else {
                            C[row*N + col] += sum;
                        }
                    }
                }
            }
        }
    }
