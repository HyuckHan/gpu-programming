# lab07 — coalescing과 thread coarsening
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# 실습실 PC는 전량 RTX 4060(sm_89)이라 거기서는 항상 sm_89가 잡힌다.
# 다른 GPU가 꽂힌 PC에서도 플래그를 직접 치지 않아도 되도록 로컬 GPU의
# compute capability를 조회해서 쓰고, 조회에 실패하면 sm_89로 둔다.
DETECTED_CC := $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.')
ARCH        ?= sm_$(if $(DETECTED_CC),$(DETECTED_CC),89)
NVCCFLAGS   := -arch=$(ARCH) -O3

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := ../../common/common.cuh

# make run 이 쓸 기본 인자.  make run N=2048 TILE=32 C=2  처럼 바꿀 수 있다.
N    ?= 4096
TILE ?= 16
C    ?= 4

all: matmul

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: matmul
	./matmul $(N) $(TILE) $(C)

test: matmul
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "lab07 — coalescing과 thread coarsening"
	@echo ""
	@echo "  make               matmul 을 빌드한다"
	@echo "  make run           ./matmul $(N) $(TILE) $(C) 실행"
	@echo "  make test          verify.py 로 자체 점검한다"
	@echo "  make clean         빌드 산출물을 지운다"
	@echo ""
	@echo "  ./sweep.sh size    N 을 바꿔가며 측정한다"
	@echo "  ./sweep.sh coarse  COARSE_FACTOR 를 바꿔가며 측정한다"
	@echo ""
	@echo "실행 인자   ./matmul <N> <TILE_DIM> <COARSE_FACTOR>   기본값 4096 16 4"
	@echo "            TILE_DIM 은 8/16/32, COARSE_FACTOR 는 1/2/4/8"
	@echo "            N 은 TILE_DIM*COARSE_FACTOR 의 배수여야 한다"

.PHONY: all run test clean help
