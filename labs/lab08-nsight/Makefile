ARCH ?= native
# lab08 — Nsight Compute
# nvcc 플래그는 여기서 관리한다. 직접 칠 필요 없다.
#
# 이 랩에는 새로 만드는 소스가 없다. matmul.cu 는 lab06 에서 완성한 커널이고
# 배포 zip 에 함께 들어 있다. 여기서는 그것을 도구로 들여다보기만 한다.

NVCC := nvcc

# -arch=$(ARCH) 는 이 PC에 꽂혀 있는 GPU에 맞춰 빌드한다 (CUDA 11.5 이상).
# 폴백을 두지 않는다. 감지에 실패하면 빌드가 실패하는 것이 옳다. 조용히 다른
# 아키텍처로 빌드되면 실행 시점에 no kernel image is available 이 뜨고
# 원인을 찾기 어렵다.
#
# -lineinfo 가 이 랩에서는 필수다. 이것이 없으면 ncu 가 metric 을 소스 줄과
# 연결하지 못하고 함수 이름까지만 보여 준다. lab03 에서 compute-sanitizer 에
# 줄 번호를 얻으려고 붙였던 것과 같은 플래그다. 최적화에는 영향이 없다.
#
# common.cuh 는 저장소에서는 ../../common/ 에, 배포 zip 에서는 같은 디렉터리에 있다.
COMMON_DIR ?= $(if $(wildcard common.cuh),.,../../common)
NVCCFLAGS  := -arch=$(ARCH) -O3 -lineinfo -I$(COMMON_DIR)
COMMON     := $(COMMON_DIR)/common.cuh

# 프로파일링에 쓸 세 지표.
METRICS := sm__throughput.avg.pct_of_peak_sustained_elapsed,\
gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed,\
sm__warps_active.avg.pct_of_peak_sustained_active

# make prof 가 쓸 기본 인자.  make prof N=4096  처럼 바꿀 수 있다.
N    ?= 1024
TILE ?= 16

all: matmul

matmul: matmul.cu $(COMMON)
	$(NVCC) $(NVCCFLAGS) -o $@ matmul.cu

run: matmul
	./matmul $(N) $(TILE)

# 두 커널을 차례로 프로파일링한다. 명령을 직접 쳐 보는 것이 이 랩의 목적이므로
# 이 타깃은 편의용이다. README 의 명령을 그대로 쳐도 된다.
prof: matmul
	ncu --metrics $(METRICS) --kernel-name mm_kernel       --launch-count 1 ./matmul $(N) $(TILE)
	ncu --metrics $(METRICS) --kernel-name mm_tiled_kernel --launch-count 1 ./matmul $(N) $(TILE)

basic: matmul
	ncu --set basic ./matmul $(N) $(TILE)

clean:
	rm -f matmul

help:
	@echo "lab08 — Nsight Compute"
	@echo ""
	@echo "  make          matmul 을 빌드한다 (-lineinfo 포함)"
	@echo "  make run      ./matmul $(N) $(TILE) 실행"
	@echo "  make prof     두 커널을 세 지표로 프로파일링한다"
	@echo "  make prof N=4096   문제 크기를 바꿔서"
	@echo "  make basic    ncu --set basic 요약 화면"
	@echo "  make clean    빌드 산출물을 지운다"
	@echo ""
	@echo "이 랩에는 채울 TODO 가 없다. matmul.cu 는 lab06 에서 완성한 커널이다."
	@echo "명령을 직접 쳐 보는 것이 실습이므로 README 를 따라가라."

.PHONY: all run prof basic clean help
