# lab12 — 스캔 (Kogge-Stone)
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

# make run 이 쓸 기본 인자.  make run N=262144  처럼 바꿀 수 있다.
N ?= 1048576

all: scan

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: scan
	./scan $(N)

test: scan
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "lab12 — 스캔 (Kogge-Stone)"
	@echo ""
	@echo "  make          scan 을 빌드한다"
	@echo "  make run      ./scan $(N) 실행"
	@echo "  make test     verify.py 로 자체 점검한다"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./scan <N>      기본값 1048576 (1<<20)"
	@echo "            N 은 1024의 배수, 1048576 이하"

.PHONY: all run test clean help
