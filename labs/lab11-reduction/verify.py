#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

reduce 를 빌드하고 돌려서 shared 커널(필수 과제)의 검증 통과 여부를 판정한다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

SIZES = [1 << 26, 1 << 20]      # 기본 크기와 작은 크기


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def shared_result(out):
    """'=== 합계 ===' 절에서 shared 줄만 읽는다. 성능 절에도 같은 이름이 나온다."""
    head = out.split("=== 성능 ===")[0]
    m = re.search(r"^shared\s*:\s*(.+)$", head, re.MULTILINE)
    return m.group(1).strip() if m else None


def main():
    print("=" * 60)
    print("리덕션 — 자체 점검 (필수 과제: shared)")
    print("=" * 60)

    print("\n[1/2] 빌드")
    build = run(["make", "reduce"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다. 괄호와 세미콜론 짝을 먼저 확인하라.")
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for n in SIZES:
        label = f"  N={n:<12}"
        try:
            r = run([str(HERE / "reduce"), str(n)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append(n)
            continue

        line = shared_result(r.stdout)
        if line is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append(n)
            continue

        print(f"{label} shared : {line}")
        if "PASS" not in line:
            failed.append(n)

    print("\n" + "=" * 60)
    if failed:
        print("결과: 실패 " + ", ".join(f"N={n}" for n in failed))
        src = (HERE / "reduce.cu").read_text(encoding="utf-8")
        if "TODO: 슬라이드 16" in src:
            print("reduce.cu의 reduce_shared_kernel 에 아직 TODO가 남아 있다.")
            print("슬라이드 16을 옮겨 채워라.")
        else:
            print("합계가 어긋난다면 input_s 적재나 stride 루프를 다시 보라.")
            print("특히 __syncthreads() 를 두 곳 모두 넣었는지 확인하라.")
            print("  (1) 적재 직후   (2) 트리의 각 단계 끝")
        return 1

    print("결과: shared 커널 통과")
    print("제출해도 된다. coarsened 는 선택 과제라 점검에 넣지 않는다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
