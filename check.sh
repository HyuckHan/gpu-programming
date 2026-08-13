#!/usr/bin/env bash
# check.sh — 정답본으로 전 랩을 빌드·실행해 4060 Ti 에서 현상을 확인한다.
#
#   bash check.sh 2>&1 | tee 4060ti.log
#
# labs/ 는 절대 수정하지 않는다. /tmp/chk 에 복사해서 작업한다.
# 랩 디렉터리명이나 실행 파일명이 다르면 아래 run_lab() 의 case 문만 고치면 된다.

set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK=/tmp/chk

hr()  { echo; echo "=================== $* ==================="; }
run() { echo; echo "\$ $*"; eval "$@"; }

# 랩 디렉터리를 /tmp 에 펼치고 정답본을 덮어쓴 뒤 빌드한다.
prepare() {
  local dir="$1" name key
  name="$(basename "$dir")"
  key="${name%%-*}"                      # lab06-tiled-matmul → lab06

  rm -rf "$WORK"; cp -r "$dir" "$WORK"
  cp "$ROOT/common/common.cuh" "$WORK/" 2>/dev/null

  # 랩 간 의존 파일
  case "$name" in
    lab04-*) cp "$ROOT"/labs/lab02-*/vecadd.cu  "$WORK/" 2>/dev/null ;;
    lab08-*) cp "$ROOT"/solutions/lab06/skeleton.cu "$WORK/matmul.cu" 2>/dev/null ;;
    lab09-*) cp "$ROOT"/labs/lab03-*/pgm.h      "$WORK/" 2>/dev/null ;;
  esac

  # 정답본 덮어쓰기
  if [ -d "$ROOT/solutions/$key" ]; then
    cp "$ROOT/solutions/$key"/* "$WORK/" 2>/dev/null
    echo "[정답본 적용: solutions/$key]"
  else
    echo "[정답본 없음: $key — TODO 상태로 실행됨]"
  fi

  (cd "$WORK" && make 2>&1 | tee /tmp/build.log | grep -Ei "error|declared but never referenced")
  return 0
}

run_lab() {
  local dir="$1" name
  name="$(basename "$dir")"
  hr "$name"
  prepare "$dir" || return
  cd "$WORK" || return

  case "$name" in
    lab01-*)
      make loop_order >/dev/null 2>&1
      run "./warmup"
      run "./loop_order"
      make hello >/dev/null 2>&1 && run "./hello"
      ;;
    lab02-*)
      make vecadd_naive >/dev/null 2>&1
      run "./vecadd --info"
      run "./vecadd"
      run "./vecadd_naive"
      for b in 32 64 128 256 512 1024; do run "./vecadd 9999999 $b"; done
      ;;
    lab03-*)
      make blur_naive >/dev/null 2>&1
      run "./blur 512 512 8"
      run "./blur_naive 512 512 8"
      run "compute-sanitizer --print-limit 3 ./blur_naive 512 512 8"
      ;;
    lab04-*)
      run "./divergence"
      run "./divergence 4194304 4000 256"
      ;;
    lab05-*)
      run "./matmul 4096 16"
      ;;
    lab06-*)
      make broken_syncthreads >/dev/null 2>&1
      for t in 8 16 32; do run "./matmul 4096 $t"; done
      for i in 1 2 3 4 5; do run "./broken_syncthreads 4096 8"; done
      ;;
    lab07-*)
      run "./matmul 4096 16 4"
      run "bash sweep.sh size"
      run "bash sweep.sh coarse"
      ;;
    lab08-*)
      # 소스가 없는 랩이다. matmul.cu 는 lab06 정답본을 복사한 것이다.
      # 세 지표가 실제로 값을 내는지, 두 문제 크기에서 어떻게 달라지는지 본다.
      M=sm__throughput.avg.pct_of_peak_sustained_elapsed,gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed,sm__warps_active.avg.pct_of_peak_sustained_active
      run "ncu --version"
      for n in 1024 4096; do
        for k in mm_kernel mm_tiled_kernel; do
          run "ncu --metrics $M --kernel-name $k --launch-count 1 ./matmul $n 16"
        done
      done
      run "ncu --set basic ./matmul 1024 16"
      ;;
    lab09-*)
      run "./conv_const"
      run "./conv_global"
      run "bash sweep.sh"
      ;;
    lab10-*)
      for i in 1 2 3; do run "./histogram"; done
      run "./histogram --skewed"
      ;;
    lab11-*)
      make assoc >/dev/null 2>&1
      run "./assoc"
      run "./reduce"
      ;;
    lab12-*)
      for i in 1 2 3; do run "./scan"; done
      ;;
    *) echo "[실행 규칙 없음 — case 문에 추가할 것]" ;;
  esac
  cd "$ROOT" || exit
}

hr "환경"
run "nvidia-smi --query-gpu=name,compute_cap,memory.total --format=csv"
run "nvcc --version | tail -2"
run "ncu --version | tail -1"

for d in "$ROOT"/labs/*/; do
  [ -f "$d/Makefile" ] || [ -f "$d/README.md" ] || continue
  run_lab "$d"
done

hr "요약"
echo "아래 항목이 비어 있어야 정상이다."
echo
echo "--- TODO 미완성 (정답본 누락)"
grep -n "declared but never referenced" /tmp/*.log 2>/dev/null
echo
echo "--- 빌드 오류"
grep -in "error" /tmp/build.log 2>/dev/null
echo
echo "확인은 4060-검증-체크리스트.md 의 항목별 기준을 따른다."
