# 12주차 — 리덕션 5단계 최적화 사다리
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc
CC   := gcc

# -arch=native 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
NVCCFLAGS  := -arch=native -O3 -I$(COMMON_DIR)
COMMON     := $(COMMON_DIR)/common.cuh

# -ffast-math 를 쓰지 않는다. 그 옵션은 컴파일러에게 덧셈 순서를 마음대로
# 바꿔도 된다고 허락하는 것이라, 이 랩이 보여주려는 현상 자체가 사라진다.
CFLAGS      := -O2 -std=c99

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := $(COMMON)

# make run 이 쓸 기본 인자.  make run N=16777216  처럼 바꿀 수 있다.
N ?= 67108864

# 기본 타깃은 reduce 하나뿐이다. assoc 은 `make assoc` 으로 따로 빌드한다.
all: reduce

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

assoc: assoc.c
	$(CC) $(CFLAGS) -o $@ assoc.c

ulp: ulp.c
	$(CC) $(CFLAGS) -o $@ ulp.c -lm

run: reduce
	./reduce $(N)

test: reduce
	python3 verify.py

clean:
	rm -f $(TARGETS) assoc ulp

help:
	@echo "12주차 — 리덕션 5단계 최적화 사다리"
	@echo ""
	@echo "  make          reduce 를 빌드한다"
	@echo "  make assoc    워밍업용 assoc 을 빌드한다 (gcc)"
	@echo "  make ulp      float 간격을 살펴보는 ulp 를 빌드한다 (gcc)"
	@echo "  make run      ./reduce $(N) 실행"
	@echo "  make test     verify.py 로 자체 점검한다"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./reduce <N>      기본값 67108864 (2^26, 256MB)"
	@echo "            N 은 2의 거듭제곱, 2048 이상 2^28 이하"
	@echo "인자 바꾸기 make run N=16777216"

.PHONY: all run test clean help
