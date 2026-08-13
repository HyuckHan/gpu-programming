ARCH ?= native
# 1주차 — 환경 확인과 C 워밍업
#
# 기본 타깃에는 gcc로 빌드하는 것만 넣는다.
# nvcc가 아직 준비되지 않은 PC에서도 make가 성공해야 후반 실습을 할 수 있다.
# hello 는 `make hello` 로 따로 빌드한다.

CC      := gcc
NVCC    := nvcc

# -ffast-math 를 쓰지 않는다. 컴파일러가 덧셈 순서를 바꾸면
# loop_order 의 두 결과가 왜 같은지 설명할 수 없게 된다.
CFLAGS  := -O2 -std=gnu99

all: warmup loop_order

warmup: warmup.c
	$(CC) $(CFLAGS) -o $@ warmup.c -lm

loop_order: loop_order.c
	$(CC) $(CFLAGS) -o $@ loop_order.c -lm

hello: hello.cu
	$(NVCC) -arch=$(ARCH) -O3 -o $@ hello.cu

clean:
	rm -f warmup loop_order hello

help:
	@echo "1주차 — 환경 확인과 C 워밍업"
	@echo ""
	@echo "  make          warmup 과 loop_order 를 빌드한다 (gcc만 있으면 된다)"
	@echo "  make hello    hello 를 빌드한다 (nvcc 필요)"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "실행        ./hello"
	@echo "            ./warmup <N>       기본값 512"
	@echo "            ./loop_order <N>   기본값 1024"

.PHONY: all clean help
