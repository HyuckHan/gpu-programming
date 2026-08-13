# 6주차 — 공유 메모리 타일링 행렬곱
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC      := nvcc

# -arch=native 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
NVCCFLAGS  := -arch=native -O3 -I$(COMMON_DIR)
COMMON     := $(COMMON_DIR)/common.cuh

TARGETS   := matmul broken_syncthreads

# make run 이 쓸 기본 인자.  make run N=1024 TILE=32  처럼 바꿀 수 있다.
# TILE 기본값은 16 이다. 32 는 블록당 1024 스레드라 occupancy 가 떨어진다.
# 32 는 스윕에서 관찰하는 값이지 기본값이 아니다.
N    ?= 4096
TILE ?= 16

# 기본 타깃은 matmul 하나뿐이다.
# broken_syncthreads 는 관찰 과제라 `make broken_syncthreads` 로 따로 빌드한다.
all: matmul

matmul: skeleton.cu $(COMMON)
	$(NVCC) $(NVCCFLAGS) -o $@ skeleton.cu

broken_syncthreads: broken_syncthreads.cu $(COMMON)
	$(NVCC) $(NVCCFLAGS) -o $@ broken_syncthreads.cu

run: matmul
	./matmul $(N) $(TILE)

test: matmul
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "6주차 — 공유 메모리 타일링 행렬곱"
	@echo ""
	@echo "  make                     스켈레톤(skeleton.cu)을 matmul 로 빌드한다"
	@echo "  make broken_syncthreads  관찰용을 빌드한다"
	@echo "  make run                 ./matmul $(N) $(TILE) 실행"
	@echo "  make test                verify.py 로 자체 점검한다"
	@echo "  make clean               빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./matmul <N> <TILE_DIM>     기본값 4096 16"
	@echo "            TILE_DIM 은 8, 16, 32 중 하나. N 은 그 배수여야 한다"
	@echo "인자 바꾸기 make run N=1024 TILE=16"

.PHONY: all run test clean help
