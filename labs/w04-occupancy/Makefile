# 4주차 — 워프와 Occupancy
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC      := nvcc
NVCCFLAGS := -arch=native -O3

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)

# 이 디렉터리에는 vecadd.cu 와 common.cuh 가 함께 들어 있어야 한다.
# 둘 다 2주차 실습에서 쓰던 파일 그대로다.
ifeq ($(wildcard common.cuh),)
ifneq ($(MAKECMDGOALS),clean)
$(error common.cuh 가 없다. 2주차 폴더의 vecadd.cu 와 common.cuh 를 이 디렉터리에 복사하라)
endif
endif

# make run 이 쓸 기본 인자.  make run N=1048576 IT=4000 B=128  처럼 바꿀 수 있다.
N  ?= 4194304
IT ?= 2000
B  ?= 256

all: $(TARGETS)

%: %.cu common.cuh
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
	@echo "  make          vecadd 와 divergence 를 빌드한다"
	@echo "  make info     ./vecadd --info 실행 (하드웨어 한계)"
	@echo "  make run      ./divergence $(N) $(IT) $(B) 실행"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./divergence <N> <iters> <blockDim>   기본값 4194304 2000 256"
	@echo "            blockDim 은 32~1024 의 32의 배수"
	@echo "            ./vecadd <N> <blockDim>  또는  ./vecadd --info"

.PHONY: all run info clean help
