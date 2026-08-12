# lab10 — 히스토그램과 데이터 경쟁
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
