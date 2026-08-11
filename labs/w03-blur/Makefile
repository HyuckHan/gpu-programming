# 3주차 — blur와 경계 조건
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# 실습실 PC는 전량 RTX 4060(sm_89)이라 거기서는 항상 sm_89가 잡힌다.
# 다른 GPU가 꽂힌 PC에서도 플래그를 직접 치지 않아도 되도록 로컬 GPU의
# compute capability를 조회해서 쓰고, 조회에 실패하면 sm_89로 둔다.
DETECTED_CC := $(shell nvidia-smi --query-gpu=compute_cap --format=csv,noheader 2>/dev/null | head -1 | tr -d '.')
ARCH        ?= sm_$(if $(DETECTED_CC),$(DETECTED_CC),89)
# -lineinfo 는 compute-sanitizer가 오류 지점을 소스 줄 번호로 찍게 해 준다.
# 최적화에는 영향이 없다.
NVCCFLAGS   := -arch=$(ARCH) -O3 -lineinfo

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := pgm.h ../../common/common.cuh

# make run 이 쓸 기본 인자.  make run W=256 H=256 B=3  처럼 바꿀 수 있다.
W ?= 512
H ?= 512
B ?= 8

# 기본 타깃은 blur 하나뿐이다.
# blur_naive 는 실습 순서에 따라 학생이 직접 `make blur_naive` 로 빌드한다.
all: blur

%: %.cu $(DEPS)
	$(NVCC) $(NVCCFLAGS) -o $@ $<

run: blur
	./blur $(W) $(H) $(B)

test: blur
	python3 verify.py

clean:
	rm -f $(TARGETS) out.pgm

.PHONY: all run test clean
