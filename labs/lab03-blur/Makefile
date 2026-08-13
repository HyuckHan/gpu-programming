ARCH ?= native
# 3주차 — blur와 경계 조건
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.

NVCC := nvcc

# -arch=$(ARCH) 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
# pgm.h 는 양쪽 모두 이 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
COMMON     := $(COMMON_DIR)/common.cuh

# -lineinfo 는 compute-sanitizer가 오류 지점을 소스 줄 번호로 찍게 해 준다.
# 최적화에는 영향이 없다.
NVCCFLAGS  := -arch=$(ARCH) -O3 -lineinfo -I$(COMMON_DIR)

SRCS    := $(wildcard *.cu)
TARGETS := $(SRCS:.cu=)
DEPS    := $(COMMON) pgm.h

# make run 이 쓸 기본 인자.  make run W=256 H=256 B=3  처럼 바꿀 수 있다.
W ?= 512
H ?= 512
B ?= 1

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

help:
	@echo "3주차 — blur와 경계 조건"
	@echo ""
	@echo "  make              blur 를 빌드한다"
	@echo "  make blur_naive   관찰용(슬라이드 17)을 빌드한다"
	@echo "  make run          ./blur $(W) $(H) $(B) 실행"
	@echo "  make test         verify.py 로 자체 점검한다"
	@echo "  make clean        빌드 산출물과 out.pgm 을 지운다"
	@echo ""
	@echo "실행 인자   ./blur <width> <height> <BLUR_SIZE>   기본값 512 512 1"
	@echo "            BLUR_SIZE 는 1 이상"
	@echo "인자 바꾸기 make run W=256 H=256 B=3"
	@echo "입력 이미지 python3 make_input.py 로 input.pgm 을 만들 수 있다"

.PHONY: all run test clean help
