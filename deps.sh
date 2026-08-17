#!/usr/bin/env bash
# deps.sh — 랩 간 의존 파일 규칙. 여기가 유일한 출처다.
#
# 랩 디렉터리에는 없지만 배포 zip 과 검증 스크립트에서는 함께 있어야 하는
# 파일을 적는다. 같은 규칙이 Makefile, check.sh, check_solutions.sh 세 곳에
# 흩어져 있어 서로 어긋났다. 이제 세 곳 모두 이 파일만 본다.
#
#   . ./deps.sh
#   copy_lab_deps <저장소루트> <랩디렉터리명> <대상디렉터리> [--solutions]
#
# 대상 이름을 함께 적는 이유는 이름이 바뀌는 경우가 있기 때문이다.
# lab06 의 소스는 skeleton.cu 인데 lab08 은 matmul.cu 를 찾는다.
#
# common/common.cuh 는 lab01 을 뺀 전 랩 공통이라 lab_deps 에 적지 않는다.
# copy_lab_deps 가 직접 넣는다.

# 랩별 추가 파일. 형식: 원본경로:대상이름  (원본 경로는 저장소 루트 기준)
lab_deps() {
    case "$1" in
        lab04-*) echo "labs/lab02-vecadd/vecadd.cu:vecadd.cu" ;;
        lab08-*) echo "solutions/lab06/skeleton.cu:matmul.cu" ;;
        lab09-*) echo "labs/lab03-blur/pgm.h:pgm.h" ;;
    esac
}

# 원본이 없으면 경고를 찍고 실패한다. 조용히 넘어가면 배포 zip 이나 검증 로그의
# 한 랩이 통째로 비고, 그때는 원인을 찾기 어렵다.
_dep_cp() {
    if [ ! -f "$1" ]; then
        echo "!! deps.sh: 의존 파일 원본이 없다 — $1" >&2
        return 1
    fi
    cp "$1" "$2" || return 1
}

# 정답본 검증용 경로 변환.
# labs/lab02-vecadd/vecadd.cu → solutions/lab02/vecadd.cu (있으면)
# 정답본 파일명은 원본과 같게 유지하기로 했으므로 이 변환이 성립한다.
# labs/ 밖을 가리키는 항목(lab08 의 solutions/lab06/skeleton.cu)은 그대로 둔다.
_dep_solution_path() {
    local root="$1" src="$2" key base cand
    case "$src" in
        labs/*) ;;
        *) echo "$src"; return 0 ;;
    esac
    base="${src##*/}"
    key="${src#labs/}"
    key="${key%%-*}"                       # lab02-vecadd/vecadd.cu → lab02
    cand="solutions/$key/$base"
    if [ -f "$root/$cand" ]; then echo "$cand"; else echo "$src"; fi
}

# 랩 디렉터리에 딸린 파일을 넣는다.
#   --solutions 를 주면 labs/ 대신 solutions/ 의 같은 이름 파일을 쓴다.
#   (검증 스크립트용. 배포 zip 은 스켈레톤을 넣어야 하므로 주지 않는다)
copy_lab_deps() {
    local root="$1" lab="$2" dest="$3" mode="${4:-}"
    local spec src dst

    # lab01 은 CUDA 를 쓰지 않는다
    case "$lab" in
        lab01-*) ;;
        *) _dep_cp "$root/common/common.cuh" "$dest/common.cuh" || return 1 ;;
    esac

    while IFS= read -r spec; do
        [ -z "$spec" ] && continue
        src="${spec%%:*}"
        dst="${spec##*:}"
        if [ "$mode" = "--solutions" ]; then
            src="$(_dep_solution_path "$root" "$src")"
        fi
        _dep_cp "$root/$src" "$dest/$dst" || return 1
    done <<< "$(lab_deps "$lab")"

    return 0
}
