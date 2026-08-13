#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

stencil 을 빌드하고 돌려서 register 커널(필수 과제)을 판정한다.
판정 기준은 두 가지다.

  1. 공유 메모리가 coarse 보다 줄었는가   — 레지스터로 옮겼는지
  2. 결과가 CPU 참조와 일치하는가         — 옮기면서 망가뜨리지 않았는지

둘 다 통과해야 한다. 표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

SIZES = [256, 128, 66]      # 기본 크기, 작은 크기, 타일로 나누어떨어지지 않는 크기


def run(cmd, timeout=900):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def kernel_row(out, name):
    """표에서 커널 한 줄을 읽는다."""
    m = re.search(rf"^{name}\s+(.+)$", out, re.MULTILINE)
    return m.group(1).strip() if m else None


def shared_bytes(out, name):
    """'... 12288 B ...' 에서 바이트 수를 뽑는다."""
    row = kernel_row(out, name)
    if row is None:
        return None
    m = re.search(r"(\d+)\s*B", row)
    return int(m.group(1)) if m else None


def main():
    print("=" * 62)
    print("stencil — 자체 점검 (필수 과제: register tiling)")
    print("=" * 62)

    print("\n[1/2] 빌드")
    build = run(["make", "stencil"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다.")
        print("  inPrev, inNext 를 float 로 바꿨다면 그 뒤에 남은 [threadIdx.y][threadIdx.x]")
        print("  첨자도 모두 지웠는지 확인하라. 네 군데다.")
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for n in SIZES:
        label = f"  N={n:<5}"
        try:
            r = run([str(HERE / "stencil"), str(n)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append(n)
            continue

        row = kernel_row(r.stdout, "register")
        if row is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append(n)
            continue

        s_reg = shared_bytes(r.stdout, "register")
        s_cos = shared_bytes(r.stdout, "coarse")
        print(f"{label} register : {row}")

        if "(미구현)" in row or (s_reg is not None and s_cos is not None and s_reg >= s_cos):
            failed.append(n)
        elif "PASS" not in row:
            failed.append(n)

    print("\n" + "=" * 62)
    if failed:
        print("결과: 실패 " + ", ".join(f"N={n}" for n in failed))
        src = (HERE / "stencil.cu").read_text(encoding="utf-8")
        if "TODO 1:" in src:
            print("stencil.cu 의 stencil_register_kernel 에 아직 TODO 가 남아 있다.")
            print("슬라이드 32 를 보고 inPrev_s 와 inNext_s 를 레지스터로 옮겨라.")
            print("슬라이드 31 과 나란히 놓고 다른 곳만 고치면 된다.")
        else:
            print("공유 메모리는 줄었는데 결과가 틀리다면 교대 부분을 다시 보라.")
            print("  inPrev = inCurr_s[...];   inCurr_s[...] = inNext;")
            print("순서가 바뀌면 아직 안 쓴 값을 덮어쓰게 된다.")
        return 1

    print("결과: register 커널 통과 (공유 메모리 감소 + 결과 일치)")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
