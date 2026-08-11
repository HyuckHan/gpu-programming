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

.PHONY: all run test clean
