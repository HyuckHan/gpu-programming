# 5주차 — 행렬곱 (naive)
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

# make run 이 쓸 기본 인자.  make run N=1024 B=32  처럼 바꿀 수 있다.
N ?= 4096
B ?= 16

all: matmul

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: matmul
	./matmul $(N) $(B)

test: matmul
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "5주차 — 행렬곱 (naive)"
	@echo ""
	@echo "  make          matmul 을 빌드한다"
	@echo "  make run      ./matmul $(N) $(B) 실행"
	@echo "  make test     verify.py 로 자체 점검한다"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./matmul <N> <blockDim>      기본값 4096 16"
	@echo "            blockDim 은 8, 16, 32 중 하나. N 은 그 배수여야 한다"
	@echo "인자 바꾸기 make run N=1024 B=32"

.PHONY: all run test clean help
