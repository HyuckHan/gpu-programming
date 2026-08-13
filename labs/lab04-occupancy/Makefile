# 4주차 — 워프와 Occupancy
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# -arch=native 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
NVCCFLAGS  := -arch=native -O3 -I$(COMMON_DIR)
COMMON     := $(COMMON_DIR)/common.cuh

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)

# make run 이 쓸 기본 인자.  make run N=1048576 IT=4000 B=128  처럼 바꿀 수 있다.
N  ?= 4194304
IT ?= 2000
B  ?= 256

# 기본 타깃은 divergence 하나뿐이다.
# vecadd 는 2주차에서 가져온 것이라 `make vecadd` 로 따로 빌드한다.
all: divergence

%: %.cu $(COMMON)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: divergence
	./divergence $(N) $(IT) $(B)

info: vecadd
	./vecadd --info

clean:
	rm -f $(TARGETS)

help:
	@echo "4주차 — 워프와 Occupancy"
	@echo ""
	@echo "  make          divergence 를 빌드한다"
	@echo "  make vecadd   2주차에서 가져온 vecadd 를 빌드한다"
	@echo "  make info     ./vecadd --info 실행 (하드웨어 한계)"
	@echo "  make run      ./divergence $(N) $(IT) $(B) 실행"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./divergence <N> <iters> <blockDim>   기본값 4194304 2000 256"
	@echo "            blockDim 은 32~1024 의 32의 배수"
	@echo "            ./vecadd <N> <blockDim>  또는  ./vecadd --info"

.PHONY: all run info clean help
