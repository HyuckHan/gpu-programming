# lab09 — 컨볼루션과 상수 메모리
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# 실습실 PC는 전량 RTX 4060(sm_89)이라 거기서는 항상 sm_89가 잡힌다.
# 다른 GPU가 꽂힌 PC에서도 플래그를 직접 치지 않아도 되도록 로컬 GPU의
# compute capability를 조회해서 쓰고, 조회에 실패하면 sm_89로 둔다.
DETECTED_CC := $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.')
ARCH        ?= sm_$(if $(DETECTED_CC),$(DETECTED_CC),89)

# FILTER_RADIUS는 상수 메모리 배열의 크기를 정하므로 컴파일 시점에 박힌다.
# 값을 바꾸려면 다시 빌드해야 한다.  make RADIUS=4  처럼 넘긴다.
RADIUS      ?= 2
NVCCFLAGS   := -arch=$(ARCH) -O3 -DFILTER_RADIUS=$(RADIUS)

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)

# 이 디렉터리에는 pgm.h 와 common.cuh 가 함께 들어 있어야 한다.
# pgm.h 는 lab03 에서, common.cuh 는 common/ 에서 복사해 온 것이다.
ifeq ($(wildcard pgm.h),)
ifneq ($(MAKECMDGOALS),clean)
$(error pgm.h 가 없다. lab03 의 pgm.h 와 common/common.cuh 를 이 디렉터리에 복사하라)
endif
endif

# make run 이 쓸 기본 인자.  make run W=2048 H=2048  처럼 바꿀 수 있다.
W ?= 4096
H ?= 4096

all: $(TARGETS)

%: %.cu pgm.h common.cuh
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: conv_const
	./conv_const $(W) $(H)

test: all
	python3 verify.py

clean:
	rm -f $(TARGETS) out.pgm

help:
	@echo "lab09 — 컨볼루션과 상수 메모리"
	@echo ""
	@echo "  make               conv_const 와 conv_global 을 빌드한다"
	@echo "  make RADIUS=4      FILTER_RADIUS 를 4로 두고 다시 빌드한다"
	@echo "  make run           ./conv_const $(W) $(H) 실행"
	@echo "  make test          verify.py 로 자체 점검한다"
	@echo "  make clean         빌드 산출물을 지운다"
	@echo ""
	@echo "  ./sweep.sh         RADIUS 를 바꿔가며 다시 빌드하고 측정한다"
	@echo ""
	@echo "실행 인자   ./conv_const <width> <height>   기본값 4096 4096"
	@echo "            FILTER_RADIUS 는 실행 인자가 아니다. 빌드할 때 정해진다"

.PHONY: all run test clean help
