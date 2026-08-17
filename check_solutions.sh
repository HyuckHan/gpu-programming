#!/usr/bin/env bash
# 정답본(solutions/)으로 전 랩을 빌드·실행한다. labs/ 는 건드리지 않는다.
#
#   bash check_solutions.sh              전 랩
#   bash check_solutions.sh lab06        하나만
#
# 각 랩을 임시 디렉터리로 복사하고, 배포 zip 과 같은 방식으로 딸린 파일
# (common.cuh, pgm.h, lab02 의 vecadd.cu)을 넣은 뒤, solutions/<lab> 의 파일로
# 덮어쓴다. 그래서 이 스크립트는 정답과 배포 구성을 한 번에 확인한다.
#
# 빌드 경고 중 "variable ... declared but never referenced" 는 TODO 가 덜 채워졌다는
# 신호다. 커널이 shared memory 를 선언만 하고 쓰지 않으면 이 경고가 뜬다.

set -u

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="${TMPDIR:-/tmp}/check_solutions.$$"
ONLY="${1:-}"
rc=0

# 랩 간 의존 파일 규칙은 deps.sh 에만 있다. 여기서 다시 적지 않는다.
. "$ROOT/deps.sh"

cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

# 일부러 틀리게 만든 관찰용 커널은 FAIL 이 나오는 것이 정상이다.
# 그 줄만 판정에서 뺀다. 여기 없는 FAIL 은 전부 진짜 실패다.
#   lab10 race    — atomic 없이 ++bins[b]. 데이터 경쟁 시연
#   lab11 atomic  — float 누적이 2^24 에서 묻히는 것을 보여 준다
#   lab12 race    — __syncthreads() 하나로 읽기/쓰기를 못 가르는 Kogge-Stone
expected_fail_re() {
    case "$1" in
        lab10) echo '^race' ;;
        lab11) echo '^atomic|^ *불일치:' ;;
        lab12) echo '^race' ;;
        *)     echo '^$XXXX' ;;
    esac
}

# 랩별 실행 명령. 한 줄에 하나씩. 없으면 빌드만 한다.
runs_for() {
    case "$1" in
        lab01) echo "./warmup 512" ;;
        lab02) echo "./vecadd 9999999 256" ;;
        lab03) echo "./blur 512 512 1" ;;
        lab04) echo "./divergence 4194304 2000 256" ;;
        lab05) echo "./matmul 4096 16" ;;
        lab06) echo "./matmul 4096 16"
               echo "./matmul 1024 32" ;;
        lab07) echo "./matmul 4096 16 4"
               echo "./transpose 4096 32" ;;
        # lab08 은 소스가 없다. ncu 가 세 지표를 실제로 뽑아내는지만 본다.
        lab08) echo "ncu --version >/dev/null && echo 'ncu OK'"
               echo "ncu --metrics sm__throughput.avg.pct_of_peak_sustained_elapsed,gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed,sm__warps_active.avg.pct_of_peak_sustained_active --kernel-name mm_kernel --launch-count 1 ./matmul 1024 16 2>&1 | grep -E 'sm__|gpu__'" ;;
        lab09) echo "./conv_const 2048 2048"
               echo "./conv_global 2048 2048" ;;
        lab10) echo "./histogram 67108864" ;;
        lab11) echo "./reduce 67108864" ;;
        lab12) echo "./scan 1048576" ;;
        lab13) echo "./stencil 256" ;;
    esac
}

for d in "$ROOT"/labs/*/; do
    name=$(basename "$d")          # lab06-tiled-matmul
    key="${name%%-*}"              # lab06
    [ -n "$ONLY" ] && [ "$key" != "$ONLY" ] && [ "$name" != "$ONLY" ] && continue

    sol="$ROOT/solutions/$key"
    dir="$WORK/$name"
    rm -rf "$dir"; mkdir -p "$dir"

    # 배포 zip 과 같은 구성으로 만든다. 확장자 있는 파일만 가져간다.
    cp "$d/Makefile" "$dir/"
    for f in "$d"*.cu "$d"*.c "$d"*.h "$d"*.py "$d"*.sh; do
        [ -f "$f" ] && cp "$f" "$dir/"
    done
    # 딸린 파일(common.cuh, lab04 의 vecadd.cu, lab08 의 matmul.cu, lab09 의 pgm.h)은
    # deps.sh 가 넣는다. --solutions 이므로 labs/ 대신 solutions/ 의 같은 이름
    # 파일을 쓴다. lab08 의 matmul.cu 는 원래부터 lab06 정답본이다.
    if ! copy_lab_deps "$ROOT" "$name" "$dir" --solutions; then
        echo "!! $name — 의존 파일을 넣지 못했다"
        rc=1
        continue
    fi

    # 정답본으로 덮어쓴다. 파일명이 원본과 같아야 한다.
    if [ -d "$sol" ]; then
        cp "$sol"/* "$dir/"
        tag="정답본"
    elif [ "$key" = "lab08" ]; then
        tag="lab06 정답본을 matmul.cu 로 사용"
    else
        tag="정답본 없음 — 원본 그대로"
    fi

    echo
    echo "########## $name  ($tag)"

    build=$(cd "$dir" && make 2>&1)
    if [ $? -ne 0 ]; then
        echo "!! 빌드 실패"
        echo "$build" | tail -20
        rc=1
        continue
    fi

    # TODO 미완의 지문. 정답본이라면 하나도 나오면 안 된다.
    if echo "$build" | grep -q "declared but never referenced"; then
        echo "!! 미사용 변수 경고 — TODO 가 덜 채워진 것이다"
        echo "$build" | grep "declared but never referenced"
        rc=1
    fi
    echo "$build" | grep -i "error" && rc=1

    while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        echo "--- $cmd"
        out=$(cd "$dir" && eval "$cmd" 2>&1)
        code=$?
        echo "$out"
        if [ $code -ne 0 ]; then
            echo "!! 종료 코드 $code"
            rc=1
        fi
        bad=$(echo "$out" | grep -vE "$(expected_fail_re "$key")" | grep "FAIL\|미구현\|불일치")
        if [ -n "$bad" ]; then
            echo "!! FAIL / 미구현 이 나왔다"
            echo "$bad"
            rc=1
        fi
    done <<< "$(runs_for "$key")"
done

echo
if [ $rc -eq 0 ]; then
    echo "전부 통과"
else
    echo "실패한 랩이 있다. 위의 !! 를 보라"
fi
exit $rc
