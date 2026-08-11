#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

vecadd 를 빌드하고 여러 (N, blockDim) 조합으로 돌려서 검증 통과 여부를 판정한다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, blockDim)
# 나누어떨어지지 않는 N과 딱 떨어지는 N을 함께 넣었다.
# 딱 떨어지는 쪽은 올림 계산을 잘못 고쳤을 때(항상 한 블록 더 만드는 식) 걸린다.
CONFIGS = [
    (9999999, 256),
    (9999999, 1024),
    (1000000, 32),
    (1048576, 256),
    (1, 64),
]


def run(cmd, timeout=300):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def main():
    print("=" * 60)
    print("2주차 벡터 덧셈 — 자체 점검")
    print("=" * 60)

    print("\n[1/2] 빌드")
    build = run(["make", "vecadd"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다. 괄호와 세미콜론 짝을 먼저 확인하라.")
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for n, block in CONFIGS:
        label = f"  N={n:<9} blockDim={block:<5}"
        try:
            r = run([str(HERE / "vecadd"), str(n), str(block)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((n, block))
            continue

        m = re.search(r"검증:\s*(PASS|FAIL)", r.stdout)
        if m is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append((n, block))
            continue

        print(f"{label} 검증 {m.group(1)}")
        if m.group(1) != "PASS":
            mismatch = re.search(r"첫 불일치: .*", r.stdout)
            if mismatch:
                print("   ", mismatch.group(0).strip())
            failed.append((n, block))

    print("\n" + "=" * 60)
    if failed:
        print(f"결과: 실패 {len(failed)}/{len(CONFIGS)}  "
              + ", ".join(f"(N={n}, blockDim={b})" for n, b in failed))
        src = (HERE / "vecadd.cu").read_text(encoding="utf-8")
        # 파일 맨 위 안내문에도 "TODO"라는 낱말이 있다. 실제 표시만 골라 본다.
        if "TODO: i가" in src or "TODO: numBlocks" in src:
            print("vecadd.cu에 아직 TODO가 남아 있다. 두 곳 모두 채웠는지 확인하라.")
            print("  (1) 커널의 경계 검사   (2) numBlocks 올림 계산")
        else:
            print("첫 불일치 위치를 보라.")
            print("  0 근처라면 커널이 아예 안 돌았을 수 있다 (numBlocks 확인).")
            print("  배열 끝 근처라면 마지막 블록이 빠진 것이다 (올림 확인).")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
