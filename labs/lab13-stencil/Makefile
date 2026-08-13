# lab13 — 3D stencil 최적화 사다리
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# -arch=native 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
COMMON     := $(COMMON_DIR)/common.cuh

# IN_TILE_DIM 은 3D 타일링 커널의 공유 메모리 배열 크기를 정하므로 컴파일
# 시점에 박힌다. 값을 바꾸려면 다시 빌드해야 한다.  make TILE=10  처럼 넘긴다.
# ./sweep.sh tile 이 이 재빌드를 자동으로 해 준다.
TILE       ?= 8
NVCCFLAGS  := -arch=native -O3 -DIN_TILE_DIM=$(TILE) -I$(COMMON_DIR)

# make run 이 쓸 기본 인자.  make run N=192  처럼 바꿀 수 있다.
N ?= 256

all: stencil

stencil: stencil.cu $(COMMON)
	$(NVCC) $(NVCCFLAGS) -o $@ stencil.cu

run: stencil
	./stencil $(N)

test: stencil
	python3 verify.py

clean:
	rm -f stencil

help:
	@echo "lab13 — 3D stencil 최적화 사다리"
	@echo ""
	@echo "  make               stencil 을 빌드한다"
	@echo "  make TILE=10       3D 타일링의 IN_TILE_DIM 을 10으로 두고 다시 빌드한다"
	@echo "  make run           ./stencil $(N) 실행"
	@echo "  make test          verify.py 로 자체 점검한다"
	@echo "  make clean         빌드 산출물을 지운다"
	@echo ""
	@echo "  ./sweep.sh all     네 커널을 기본 설정으로 비교한다"
	@echo "  ./sweep.sh tile    IN_TILE_DIM 을 바꿔가며 다시 빌드하고 측정한다"
	@echo ""
	@echo "실행 인자   ./stencil <N>       기본값 256 (배열 하나 64MB)"
	@echo "            N 은 8 이상 384 이하"
	@echo "            IN_TILE_DIM 은 실행 인자가 아니다. 빌드할 때 정해진다"

.PHONY: all run test clean help
