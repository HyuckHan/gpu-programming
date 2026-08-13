#!/bin/sh
# 표를 채우는 데 쓰는 스윕 스크립트.
#
#   ./sweep.sh all     네 커널을 기본 설정으로 비교한다
#   ./sweep.sh tile    3D 타일링의 IN_TILE_DIM 을 바꿔가며 다시 빌드하고 측정한다
#
# 각 줄의 숫자를 README 의 표에 그대로 옮겨 적으면 된다.

cd "$(dirname "$0")" || exit 1

N="${N:-256}"

case "$1" in
    all)
        make >/dev/null 2>&1 || { echo "빌드 실패" >&2; exit 1; }
        ./stencil "$N"
        ;;

    tile)
        # IN_TILE_DIM 은 공유 메모리 배열의 크기라 컴파일 시점에 박힌다.
        # 그래서 설정마다 다시 빌드한다.
        #
        # 12 는 실패한다. 그것이 정상이다. 3D 블록이라 스레드가 12^3 = 1728 개가
        # 되어 블록당 최대 1024 를 넘는다. 슬라이드 19~22 가 말하는 한계다.
        # 오류를 감추지 않고 그대로 보여 준다.
        TILES="${TILES:-6 8 10 12}"

        echo "3D 타일링 스윕 — N=$N, IN_TILE_DIM = $TILES"
        echo ""
        printf "%9s %11s %9s %10s %9s %12s\n" \
               "IN_TILE" "OUT_TILE" "스레드/블록" "시간" "GB/s" "공유메모리"

        for t in $TILES; do
            make clean >/dev/null 2>&1
            if ! make TILE="$t" >/dev/null 2>&1; then
                printf "%9s %11s %9s %10s %9s %12s\n" \
                       "$t" "$((t-2))" "$((t*t*t))" "빌드실패" "-" "-"
                continue
            fi

            out=$(./stencil "$N" 2>&1)
            if echo "$out" | grep -q "^tiled"; then
                echo "$out" | awk -v t="$t" '
                    /^tiled/ { printf "%9s %11s %9s %7s ms %9s %10s B\n",
                                      t, t-2, t*t*t, $2, $4, $5 }'
            else
                # 실행이 막혔다. 프로그램이 낸 메시지를 그대로 보여 준다.
                printf "%9s %11s %9s   %s\n" "$t" "$((t-2))" "$((t*t*t))" "실행 불가"
                echo "$out" | grep -v "^$" | sed 's/^/           | /'
            fi
        done

        echo ""
        echo "빌드를 기본값으로 되돌린다."
        make clean >/dev/null 2>&1
        make >/dev/null 2>&1
        ;;

    *)
        echo "사용법: ./sweep.sh all    (네 커널 비교)" >&2
        echo "        ./sweep.sh tile   (IN_TILE_DIM 스윕, 3D 타일링)" >&2
        exit 1
        ;;
esac
