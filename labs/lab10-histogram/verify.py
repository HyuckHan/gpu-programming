#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

histogram 을 빌드하고 돌려서 atomic 커널의 검증 통과 여부를 판정한다.
race 는 틀리는 것이 정상이므로 판정 대상이 아니다.
private 는 선택 과제라 판정하지 않는다. 채웠으면 결과만 함께 찍어 준다.
슬라이드에 코드가 없는 과제를 통과 조건으로 걸지 않기 위한 것이다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, --skewed 여부)
CONFIGS = [
    (1 << 26, False),
    (1 << 26, True),
    (1000003, False),   # BLOCK_DIM 으로 나누어떨어지지 않는 크기
    (255, False),       # 블록 하나도 못 채우는 크기
]


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def kernel_line(out, name):
    m = re.search(rf"^{name}\s*:\s*(.+)$", out, re.MULTILINE)
    return m.group(1).strip() if m else None


def main():
    print("=" * 62)
    print("lab10 히스토그램 — 자체 점검 (판정 대상: atomic 커널)")
    print("=" * 62)

    print("\n[1/2] 빌드")
    build = run(["make", "histogram"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip()[:800])
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for N, skewed in CONFIGS:
        argv = [str(HERE / "histogram"), str(N)] + (["--skewed"] if skewed else [])
        label = f"  N={N:<10} {'치우침' if skewed else '균등  '}"
        try:
            r = run(argv)
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((N, skewed))
            continue

        line = kernel_line(r.stdout, "atomic")
        if line is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:300])
            failed.append((N, skewed))
            continue

        print(f"{label} atomic  : {line}")
        if "PASS" not in line:
            failed.append((N, skewed))

        # private 는 선택 과제다. 판정하지 않고 상태만 알려 준다.
        priv = kernel_line(r.stdout, "private")
        if priv is not None:
            print(f"  {'':<17} private : {priv}   (선택 과제 — 판정하지 않는다)")

    print("\n" + "=" * 62)
    if failed:
        print(f"결과: 실패 {len(failed)}건")
        src = (HERE / "histogram.cu").read_text(encoding="utf-8")
        if "TODO: bins[b]" in src:
            print("histogram.cu 의 histogram_atomic_kernel 에 아직 TODO 가 남아 있다.")
            print("race 커널과 다른 곳은 한 줄뿐이다 (슬라이드 12).")
        else:
            print("점검할 것:")
            print("  • bins[b] 를 늘릴 때 atomicAdd 를 썼는가")
            print("  • 경계 검사(i < N)를 그대로 두었는가")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    print("제출해도 된다. private 커널은 선택 과제이므로 못 채웠어도 통과다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
