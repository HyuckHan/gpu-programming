# 2주차 — 벡터 덧셈
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

# make run 이 쓸 기본 인자.  make run N=1000000 B=512  처럼 바꿀 수 있다.
N ?= 9999999
B ?= 256

# 기본 타깃은 vecadd 하나뿐이다.
# vecadd_naive 는 실습 순서에 따라 학생이 직접 `make vecadd_naive` 로 빌드한다.
all: vecadd

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: vecadd
	./vecadd $(N) $(B)

test: vecadd
	python3 verify.py

clean:
	rm -f $(TARGETS)

help:
	@echo "2주차 — 벡터 덧셈"
	@echo ""
	@echo "  make               vecadd 를 빌드한다"
	@echo "  make vecadd_naive  관찰용(슬라이드 18)을 빌드한다"
	@echo "  make run           ./vecadd $(N) $(B) 실행"
	@echo "  make test          verify.py 로 자체 점검한다"
	@echo "  make clean         빌드 산출물을 지운다"
	@echo ""
	@echo "실행 인자   ./vecadd <N> <blockDim>      기본값 9999999 256"
	@echo "            blockDim 은 32~1024 의 32의 배수"
	@echo "인자 바꾸기 make run N=1000000 B=512"

.PHONY: all run test clean help
