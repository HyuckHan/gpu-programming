#!/bin/sh
# 표를 채우는 데 쓰는 스윕 스크립트.
#
#   ./sweep.sh size      N 을 바꿔가며 측정한다 (TILE_DIM=16, COARSE_FACTOR=4 고정)
#   ./sweep.sh coarse    COARSE_FACTOR 를 바꿔가며 측정한다 (N=4096, TILE_DIM=16 고정)
#
# 각 줄의 숫자를 README 의 표에 그대로 옮겨 적으면 된다.

set -e
cd "$(dirname "$0")"

if [ ! -x ./matmul ]; then
    echo "matmul 이 없다. 먼저 make 를 실행하라." >&2
    exit 1
fi

# 한 번 실행해서 세 커널의 GFLOP/s 와 배속을 뽑아낸다.
run_one() {
    # 출력 한 줄의 모양:
    #   tiled        :    122.8 ms    1118.9 GFLOP/s   1.45x
    #   $1            $2   $3    $4     $5      $6      $7
    ./matmul "$1" "$2" "$3" | awk '
        /^naive/         { g_naive = $5 }
        /^tiled  /       { g_tiled = $5; s_tiled = $7 }
        /^tiled\+coarse/ {
            if ($3 == "(미구현)") { g_coarse = "-"; s_coarse = "-" }
            else                  { g_coarse = $5; s_coarse = $7 }
        }
        END { printf "%10s %10s %8s %10s %8s\n",
                     g_naive, g_tiled, s_tiled, g_coarse, s_coarse }'
}

case "$1" in
    size)
        echo "크기 스윕 — TILE_DIM=16, COARSE_FACTOR=4 고정"
        echo ""
        printf "%6s %10s %10s %8s %10s %8s\n" \
               "N" "naive" "tiled" "배속" "coarse" "배속"
        for n in 512 1024 2048 4096 8192; do
            printf "%6s " "$n"
            run_one "$n" 16 4
        done
        ;;
    coarse)
        echo "coarsening 스윕 — N=4096, TILE_DIM=16 고정"
        echo ""
        printf "%6s %10s %10s %8s %10s %8s\n" \
               "COARSE" "naive" "tiled" "배속" "coarse" "배속"
        for c in 1 2 4 8; do
            printf "%6s " "$c"
            run_one 4096 16 "$c"
        done
        ;;
    *)
        echo "사용법: ./sweep.sh size    (N 스윕)" >&2
        echo "        ./sweep.sh coarse (COARSE_FACTOR 스윕)" >&2
        exit 1
        ;;
esac
