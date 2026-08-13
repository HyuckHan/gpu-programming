ARCH ?= native
# lab07 — coalescing과 thread coarsening
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# -arch=$(ARCH) 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
NVCCFLAGS  := -arch=$(ARCH) -O3 -I$(COMMON_DIR)
COMMON     := $(COMMON_DIR)/common.cuh

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := $(COMMON)

# make run 이 쓸 기본 인자.  make run N=2048 TILE=32 C=2  처럼 바꿀 수 있다.
N    ?= 4096
TILE ?= 16
C    ?= 4

# 실습 본체는 matmul(2·3절)과 transpose(1절) 둘이다.
all: matmul transpose

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: matmul
	./matmul $(N) $(TILE) $(C)

runt: transpose
	./transpose $(N) $(TILE)

test: matmul
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "lab07 — coalescing과 thread coarsening"
	@echo ""
	@echo "  make               matmul 과 transpose 를 빌드한다"
	@echo "  make run           ./matmul $(N) $(TILE) $(C) 실행"
	@echo "  make runt          ./transpose $(N) $(TILE) 실행"
	@echo "  make test          verify.py 로 자체 점검한다"
	@echo "  make clean         빌드 산출물을 지운다"
	@echo ""
	@echo "  ./sweep.sh transpose  TILE_DIM 을 바꿔가며 전치를 측정한다"
	@echo "  ./sweep.sh coarse     COARSE_FACTOR 를 바꿔가며 측정한다"
	@echo ""
	@echo "실행 인자   ./matmul <N> <TILE_DIM> <COARSE_FACTOR>   기본값 4096 16 4"
	@echo "            TILE_DIM 은 8/16/32, COARSE_FACTOR 는 1/2/4/8"
	@echo "            N 은 TILE_DIM*COARSE_FACTOR 의 배수여야 한다"
	@echo ""
	@echo "            ./transpose <N> <TILE_DIM>               기본값 4096 32"
	@echo "            N 은 TILE_DIM 과 32 의 배수여야 한다"

.PHONY: all run runt test clean help
