ARCH ?= native
# lab10 — 히스토그램과 데이터 경쟁
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

# make run 이 쓸 기본 인자.  make run N=16777216  처럼 바꿀 수 있다.
N ?= 67108864

all: histogram

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: histogram
	./histogram $(N)

skewed: histogram
	./histogram $(N) --skewed

test: histogram
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "lab10 — 히스토그램과 데이터 경쟁"
	@echo ""
	@echo "  make          histogram 을 빌드한다"
	@echo "  make run      ./histogram $(N) 실행"
	@echo "  make skewed   ./histogram $(N) --skewed 실행"
	@echo "  make test     verify.py 로 자체 점검한다"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./histogram <N> [--skewed]     기본값 67108864 (1<<26)"
	@echo "            --skewed 는 값의 80%를 16개 칸에 몰아 넣는다"

.PHONY: all run skewed test clean help
