#!/bin/sh
# FILTER_RADIUS 를 바꿔가며 측정한다.
#
#   ./sweep.sh
#
# FILTER_RADIUS 는 상수 메모리 배열의 크기라 컴파일 시점에 박힌다.
# 그래서 이 스크립트는 설정마다 다시 빌드한다. 시간이 좀 걸린다.
#
# 각 줄의 숫자를 README 의 표에 그대로 옮겨 적으면 된다.
# global 열은 conv_global.cu 의 TODO 를 채워야 값이 나온다. 그전에는 - 로 나온다.

set -e
cd "$(dirname "$0")"

RADII="${RADII:-1 2 4 8}"
W="${W:-4096}"
H="${H:-4096}"

echo "이미지 ${W}x${H}, FILTER_RADIUS = ${RADII}"
echo ""
printf "%7s %7s %10s %10s %10s %10s %10s %8s\n" \
       "RADIUS" "DIM" "const ms" "GB/s" "GFLOP/s" "FLOP/B" "global ms" "비율"

for r in $RADII; do
    make clean >/dev/null 2>&1 || true
    make RADIUS="$r" >/dev/null 2>&1

    out_const=$(./conv_const "$W" "$H")
    ms_const=$(echo "$out_const" | awk '/^커널/        {print $3}')
    gbps=$(    echo "$out_const" | awk '/^유효 대역폭/ {print $4}')
    gflops=$(  echo "$out_const" | awk '/^연산 처리율/ {print $4}')
    fpb=$(     echo "$out_const" | awk '/^연산\/바이트/{print $3}')

    # conv_global 은 TODO 를 채웠을 때만 유효한 값이다.
    out_global=$(./conv_global "$W" "$H" || true)
    if echo "$out_global" | grep -q "정확성: PASS"; then
        ms_global=$(echo "$out_global" | awk '/^커널/ {print $3}')
        ratio=$(awk -v a="$ms_global" -v b="$ms_const" 'BEGIN{printf "%.2f", a/b}')
    else
        ms_global="-"
        ratio="-"
    fi

    printf "%7s %7s %10s %10s %10s %10s %10s %8s\n" \
           "$r" "$((2*r+1))" "$ms_const" "$gbps" "$gflops" "$fpb" "$ms_global" "$ratio"
done
