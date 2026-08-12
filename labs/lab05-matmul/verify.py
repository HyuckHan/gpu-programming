#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

matmul.cu를 빌드하고 여러 (N, blockDim) 조합으로 돌려서
정확성 통과 여부와 성능을 출력한다. 실패하면 무엇이 틀렸는지 짚어 준다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, blockDim) — 작은 것부터. N<=1024 조합은 CPU 참조와 전부 대조된다.
CONFIGS = [(512, 8), (512, 16), (1024, 32), (4096, 16)]


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=HERE, capture_output=True,
                          text=True, timeout=timeout)


def parse(out):
    ok = re.search(r"정확성:\s*(PASS|FAIL)", out)
    gf = re.search(r"naive\s*:.*?\(\s*([0-9.]+) GFLOP/s\)", out)
    mm = re.search(r"첫 불일치: .*", out)
    return (ok.group(1) if ok else None,
            float(gf.group(1)) if gf else None,
            mm.group(0) if mm else None)


def diagnose(N, block, first_mismatch):
    """실패한 조합에 대해 짚이는 원인을 출력한다."""
    print("    ── 점검할 것 ──")
    src = (HERE / "matmul.cu").read_text(encoding="utf-8")
    if "TODO: row, col" in src or "TODO: sum" in src:
        print("    • matmul.cu에 아직 TODO가 남아 있다. 커널 본체를 채웠는지 확인하라.")
        print()
        return

    if first_mismatch and re.search(r"실제 -?0\.000000\b", first_mismatch):
        print("    • 결과가 0이다. C[row*N + col]에 sum을 쓰는 줄이 빠졌거나,")
        print("      i 루프가 한 번도 돌지 않았을 수 있다.")
    else:
        print("    • 인덱스 계산을 다시 보라.")
        print("      row는 y 방향(blockIdx.y, threadIdx.y), col은 x 방향이다.")
        print("      A는 A[row*N + i], B는 B[i*N + col] 로 읽는다. 둘을 바꾸면 전치가 된다.")
    print()


def main():
    print("=" * 60)
    print("5주차 행렬곱 — 자체 점검")
    print("=" * 60)

    print("\n[1/2] 빌드")
    build = run(["make", "matmul"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다. 세미콜론과 중괄호 짝을 먼저 확인하라.")
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed, gflops = [], {}
    for N, block in CONFIGS:
        label = f"  N={N:<5} blockDim={block:<3}"
        try:
            r = run([str(HERE / "matmul"), str(N), str(block)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((N, block))
            continue

        status, gf, mismatch = parse(r.stdout)
        if status is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append((N, block))
            continue

        print(f"{label} 정확성 {status}" + (f"   {gf:.1f} GFLOP/s" if gf else ""))
        if status == "PASS":
            gflops[(N, block)] = gf
        else:
            if mismatch:
                print("   ", mismatch)
            failed.append((N, block))
            diagnose(N, block, mismatch)

    print("\n" + "=" * 60)
    if failed:
        print(f"결과: 실패 {len(failed)}/{len(CONFIGS)}  "
              + ", ".join(f"(N={n}, blockDim={b})" for n, b in failed))
        print("위 점검 항목을 고친 뒤 다시 돌려라.")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    main_gf = gflops.get((4096, 16))
    if main_gf is not None:
        print(f"기본 조건(N=4096, blockDim=16): {main_gf:.1f} GFLOP/s")
        print("이 값을 보고서에 적어 두어라. 다음 주 타일링 버전과 비교할 기준선이다.")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
