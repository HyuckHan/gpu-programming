ARCH ?= native
# lab09 — 컨볼루션과 상수 메모리
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# -arch=$(ARCH) 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 와 pgm.h 는 배포 zip 에서는 같은 디렉터리에 함께 들어 있고,
# 저장소에서는 각각 common/ 과 lab03 에 있다. 양쪽에서 다 빌드되게 한다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
PGM_DIR    ?= $(if $(wildcard pgm.h),.,../lab03-blur)
COMMON     := $(COMMON_DIR)/common.cuh
PGM        := $(PGM_DIR)/pgm.h

# FILTER_RADIUS는 상수 메모리 배열의 크기를 정하므로 컴파일 시점에 박힌다.
# 값을 바꾸려면 다시 빌드해야 한다.  make RADIUS=4  처럼 넘긴다.
RADIUS     ?= 2
NVCCFLAGS  := -arch=$(ARCH) -O3 -DFILTER_RADIUS=$(RADIUS) -I$(COMMON_DIR) -I$(PGM_DIR)

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := $(COMMON) $(PGM)

# make run 이 쓸 기본 인자.  make run W=2048 H=2048  처럼 바꿀 수 있다.
W ?= 4096
H ?= 4096

all: $(TARGETS)

%: %.cu $(DEPS)
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
