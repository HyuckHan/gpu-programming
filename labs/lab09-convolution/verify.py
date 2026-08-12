#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

conv_global 을 빌드하고 돌려서 검증 통과 여부를 판정한다.
conv_const 는 완성 상태로 제공된 것이라 판정 대상이 아니다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (width, height) — 정사각이 아닌 크기를 함께 넣었다.
SIZES = [(1024, 1024), (1536, 1024), (4096, 4096)]

# FILTER_RADIUS 는 컴파일 시점 상수라 빌드를 다시 해야 바뀐다.
RADII = [1, 2, 4]


def run(cmd, timeout=900):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def main():
    print("=" * 62)
    print("lab09 컨볼루션 — 자체 점검 (판정 대상: conv_global)")
    print("=" * 62)

    # 자리표시자 코드가 남아 있으면 아직 안 채운 것이다.
    # 주석이 아니라 코드로 판정한다. 주석은 지우지 않고 고치는 경우가 있다.
    src = (HERE / "conv_global.cu").read_text(encoding="utf-8")
    unfilled = "sum += 1.0f*input" in src

    failed = []
    for radius in RADII:
        print(f"\n[FILTER_RADIUS = {radius}]")
        run(["make", "clean"])
        build = run(["make", f"RADIUS={radius}"])
        if build.returncode != 0:
            print("  빌드 실패\n")
            print(build.stderr.strip()[:800])
            return 1

        for width, height in SIZES:
            label = f"  {width}x{height}"
            try:
                r = run([str(HERE / "conv_global"), str(width), str(height)])
            except subprocess.TimeoutExpired:
                print(f"{label} 시간 초과")
                failed.append((radius, width, height))
                continue

            m = re.search(r"정확성:\s*(PASS|FAIL)", r.stdout)
            if m is None:
                print(f"{label} 실행 실패 (rc={r.returncode})")
                print("   ", (r.stderr.strip() or r.stdout.strip())[:300])
                failed.append((radius, width, height))
                continue

            print(f"{label} 정확성 {m.group(1)}")
            if m.group(1) != "PASS":
                mismatch = re.search(r"첫 불일치: .*", r.stdout)
                if mismatch:
                    print("   ", mismatch.group(0).strip())
                failed.append((radius, width, height))

    print("\n" + "=" * 62)
    if failed:
        print(f"결과: 실패 {len(failed)}건")
        if unfilled:
            print("conv_global.cu 의 커널에 자리표시자 1.0f 가 그대로 남아 있다.")
            print("그 자리에 전역 메모리 filter 에서 읽은 값을 넣어야 한다.")
        else:
            print("점검할 것:")
            print("  • filter 는 1차원 배열이다. filter[filterRow*FILTER_DIM + filterCol]")
            print("    처럼 두 인덱스를 합쳐야 한다")
            print("  • FILTER_DIM 대신 FILTER_RADIUS 로 곱하고 있지는 않은지 확인하라")
        return 1

    print(f"결과: 전부 통과 ({len(RADII)*len(SIZES)}/{len(RADII)*len(SIZES)})")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
