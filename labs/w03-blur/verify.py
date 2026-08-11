#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

blur.cu를 빌드하고 여러 크기로 돌려서 검증 통과 여부를 판정한다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (width, height, BLUR_SIZE)
# 정사각이 아닌 크기와 블록(16x16)으로 나누어떨어지지 않는 크기를 함께 넣었다.
CONFIGS = [(512, 512, 8), (256, 256, 3), (300, 200, 5), (64, 64, 0)]


def run(cmd, timeout=300):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def main():
    print("=" * 60)
    print("3주차 blur — 자체 점검")
    print("=" * 60)

    # input.pgm이 있으면 크기 인자가 무시되므로 점검 결과가 달라진다.
    if (HERE / "input.pgm").exists():
        print("\ninput.pgm이 있어 크기 인자가 무시된다. 점검하려면 옮겨 두어라.")
        return 1

    print("\n[1/2] 빌드")
    build = run(["make", "blur"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다. 괄호와 세미콜론 짝을 먼저 확인하라.")
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for width, height, blur_size in CONFIGS:
        label = f"  {width}x{height}  BLUR_SIZE={blur_size:<3}"
        try:
            r = run([str(HERE / "blur"), str(width), str(height), str(blur_size)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((width, height, blur_size))
            continue

        m = re.search(r"검증:\s*(PASS|FAIL)", r.stdout)
        if m is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append((width, height, blur_size))
            continue

        print(f"{label} 검증 {m.group(1)}")
        if m.group(1) != "PASS":
            mismatch = re.search(r"첫 불일치: .*", r.stdout)
            if mismatch:
                print("   ", mismatch.group(0).strip())
                idx = re.search(r"\[(\d+)\]", mismatch.group(0))
                if idx:
                    i = int(idx.group(1))
                    print(f"     → 행 {i // width}, 열 {i % width}")
            failed.append((width, height, blur_size))

    print("\n" + "=" * 60)
    if failed:
        print(f"결과: 실패 {len(failed)}/{len(CONFIGS)}  "
              + ", ".join(f"({w}x{h}, B={b})" for w, h, b in failed))
        if "TODO" in (HERE / "blur.cu").read_text(encoding="utf-8"):
            print("blur.cu에 아직 TODO가 남아 있다. 안쪽 루프를 채웠는지 확인하라.")
        else:
            print("첫 불일치가 가장자리(행이나 열이 0에 가까운 곳)에 몰려 있다면")
            print("경계 조건 네 가지 중 빠뜨린 것이 없는지 확인하라.")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
