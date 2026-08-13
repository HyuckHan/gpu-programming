#!/bin/sh
# 표를 채우는 데 쓰는 스윕 스크립트.
#
#   ./sweep.sh transpose   TILE_DIM 을 바꿔가며 전치를 측정한다 (N=4096 고정)
#   ./sweep.sh coarse      COARSE_FACTOR 를 바꿔가며 측정한다 (N=4096, TILE_DIM=16 고정)
#
# 각 줄의 숫자를 README 의 표에 그대로 옮겨 적으면 된다.
#
# 크기 스윕(N 을 바꾸는 모드)은 없앴다. 행렬곱은 N 을 512~8192 로 바꿔도
# 배속이 1.4~1.6배 사이에서 흔들릴 뿐 추세가 나오지 않는다. naive 행렬곱의
# 접근 패턴이 나쁘지 않아 L2 가 흡수해 버리기 때문이다. coalescing 은
# transpose 모드에서 본다.

set -e
cd "$(dirname "$0")"

N="${N:-4096}"

case "$1" in
    transpose)
        if [ ! -x ./transpose ]; then
            echo "transpose 가 없다. 먼저 make 를 실행하라." >&2
            exit 1
        fi

        echo "전치 스윕 — N=$N, 기준선 naive 32x32 고정"
        echo ""
        printf "%8s %10s %12s %10s %8s\n" \
               "TILE_DIM" "tiled ms" "tiled GB/s" "이론대비" "배속"

        for t in 8 16 32; do
            # 출력 한 줄의 모양:
            #   tiled 16x16      :   0.55 ms   245.7 GB/s   (이론 대비 85.3%)
            #   $1    $2         $3   $4   $5     $6   $7     $8   $9   $10
            ./transpose "$N" "$t" | awk -v t="$t" '
                /^naive 32x32/ { ms_n = $4 }
                /^tiled/       { ms = $4; gb = $6; pct = $10; sub(/\)$/, "", pct) }
                END {
                    printf "%8s %10s %12s %10s %7.2fx\n", t, ms, gb, pct, ms_n/ms
                }'
        done

        echo ""
        echo "기준선과 비교선 (TILE_DIM 과 무관하게 같다)"
        ./transpose "$N" 16 | grep "^naive"
        ;;

    coarse)
        if [ ! -x ./matmul ]; then
            echo "matmul 이 없다. 먼저 make 를 실행하라." >&2
            exit 1
        fi

        # N 은 4096 까지만 본다. 8192 에서는 coarse 의 처리율이 도리어 떨어져
        # COARSE_FACTOR 의 효과와 섞인다. 여기서 보려는 것은 그것이 아니다.
        if [ "$N" -gt 4096 ]; then
            echo "coarse 모드의 N 상한은 4096 이다 (받은 값: $N)" >&2
            exit 1
        fi

        echo "coarsening 스윕 — N=$N, TILE_DIM=16 고정"
        echo ""
        printf "%6s %10s %10s %8s %10s %8s\n" \
               "COARSE" "naive" "tiled" "배속" "coarse" "배속"
        for c in 1 2 4 8; do
            printf "%6s " "$c"
            # 출력 한 줄의 모양:
            #   tiled        :    122.8 ms    1118.9 GFLOP/s   1.45x
            #   $1            $2   $3    $4     $5      $6      $7
            ./matmul "$N" 16 "$c" | awk '
                /^naive/         { g_naive = $5 }
                /^tiled  /       { g_tiled = $5; s_tiled = $7 }
                /^tiled\+coarse/ {
                    if ($3 == "(미구현)") { g_coarse = "-"; s_coarse = "-" }
                    else                  { g_coarse = $5; s_coarse = $7 }
                }
                END { printf "%10s %10s %8s %10s %8s\n",
                             g_naive, g_tiled, s_tiled, g_coarse, s_coarse }'
        done
        ;;

    *)
        echo "사용법: ./sweep.sh transpose  (TILE_DIM 스윕, 전치)" >&2
        echo "        ./sweep.sh coarse     (COARSE_FACTOR 스윕, 행렬곱)" >&2
        exit 1
        ;;
esac
