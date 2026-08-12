# 6주차 — 공유 메모리 타일링 행렬곱
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC      := nvcc

# 실습실 PC는 전량 RTX 4060(sm_89)이라 거기서는 항상 sm_89가 잡힌다.
# 다른 GPU가 꽂힌 PC에서도 플래그를 직접 치지 않아도 되도록 로컬 GPU의
# compute capability를 조회해서 쓰고, 조회에 실패하면 sm_89로 둔다.
DETECTED_CC := $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.')
ARCH        ?= sm_$(if $(DETECTED_CC),$(DETECTED_CC),89)
NVCCFLAGS   := -arch=$(ARCH) -O3

COMMON    := ../../common/common.cuh
TARGETS   := matmul broken_syncthreads

# make run 이 쓸 기본 인자.  make run N=1024 TILE=16  처럼 바꿀 수 있다.
N    ?= 4096
TILE ?= 32

all: $(TARGETS)

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
	@echo "  make                     matmul 과 broken_syncthreads 를 빌드한다"
	@echo "  make matmul              스켈레톤(skeleton.cu)을 빌드한다"
	@echo "  make broken_syncthreads  관찰용을 빌드한다"
	@echo "  make run                 ./matmul $(N) $(TILE) 실행"
	@echo "  make test                verify.py 로 자체 점검한다"
	@echo "  make clean               빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./matmul <N> <TILE_DIM>     기본값 4096 32"
	@echo "            TILE_DIM 은 8, 16, 32 중 하나. N 은 그 배수여야 한다"
	@echo "인자 바꾸기 make run N=1024 TILE=16"

.PHONY: all run test clean help
