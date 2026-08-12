#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

skeleton.cu를 빌드하고 여러 (N, TILE_DIM) 조합으로 돌려서
정확성 통과 여부와 배속을 출력한다. 실패하면 무엇이 틀렸는지 짚어 준다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, TILE_DIM) — 작은 것부터. N<=1024 조합은 CPU 참조까지 대조된다.
CONFIGS = [(512, 8), (512, 16), (1024, 32), (4096, 32)]

# 이보다 낮으면 타일링이 실제로 동작하는지 의심스럽다.
# 기준선 naive 를 16x16 으로 고정한 뒤 정답 커널의 배속이 1.25~1.45 로 내려왔다.
# (고정 전에는 naive 가 TILE_DIM 을 따라 느려져서 배속이 부풀어 있었다.)
# 정답인데도 경고가 뜨지 않도록 그 아래에 둔다.
MIN_SPEEDUP = 1.15


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=HERE, capture_output=True,
                          text=True, timeout=timeout)


def parse(out):
    ok = re.search(r"정확성:\s*(PASS|FAIL)", out)
    sp = re.search(r"배속:\s*([0-9.]+)x", out)
    mm = re.search(r"첫 불일치: .*", out)
    return (ok.group(1) if ok else None,
            float(sp.group(1)) if sp else None,
            mm.group(0) if mm else None)


def diagnose(N, tile, out, first_mismatch):
    """실패한 조합에 대해 짚이는 원인을 출력한다."""
    print("    ── 점검할 것 ──")
    if "TODO" in (HERE / "skeleton.cu").read_text(encoding="utf-8"):
        print("    • skeleton.cu에 아직 TODO가 남아 있다. 커널 본체를 채웠는지 확인하라.")

    all_zero = bool(first_mismatch and re.search(r"실제 -?0\.000000\b", first_mismatch))
    if all_zero:
        # 결과가 통째로 0이면 아래 원인들은 따져 봐야 의미가 없다.
        print("    • 결과가 0이다. C[row*N + col]에 sum을 쓰는 줄이 빠졌거나,")
        print("      tile 루프가 한 번도 돌지 않았을 수 있다 (N/TILE_DIM 확인).")
        print()
        return

    # 같은 조합을 한 번 더 돌려서 결과가 재현되는지 본다
    again = run([str(HERE / "matmul"), str(N), str(tile)])
    _, _, mm2 = parse(again.stdout)
    if first_mismatch and mm2 and first_mismatch != mm2:
        print("    • 실행할 때마다 틀리는 위치나 값이 달라진다. 스레드끼리 shared memory를")
        print("      기다려 주지 않고 있다는 뜻이다. 동기화 지점을 다시 보라.")
    elif first_mismatch and mm2 == first_mismatch:
        print("    • 매번 같은 곳에서 같은 값이 틀린다. 인덱스 계산 오류일 가능성이 크다.")
        print("      A는 행 방향(row*N + ...), B는 열 방향((...)*N + col)으로 읽는다.")
    print()


def main():
    print("=" * 60)
    print("6주차 타일링 행렬곱 — 자체 점검")
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
    failed, speedups = [], {}
    for N, tile in CONFIGS:
        label = f"  N={N:<5} TILE_DIM={tile:<3}"
        try:
            r = run([str(HERE / "matmul"), str(N), str(tile)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((N, tile))
            continue

        status, speedup, mismatch = parse(r.stdout)
        if status is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append((N, tile))
            continue

        print(f"{label} 정확성 {status}"
              + (f"   배속 {speedup:.2f}x" if speedup else ""))
        if status == "PASS":
            speedups[(N, tile)] = speedup
        else:
            if mismatch:
                print("   ", mismatch)
            failed.append((N, tile))
            diagnose(N, tile, r.stdout, mismatch)

    print("\n" + "=" * 60)
    if failed:
        print(f"결과: 실패 {len(failed)}/{len(CONFIGS)}  "
              + ", ".join(f"(N={n}, TILE_DIM={t})" for n, t in failed))
        print("위 점검 항목을 고친 뒤 다시 돌려라.")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    main_speedup = speedups.get((4096, 32))
    if main_speedup is not None:
        print(f"기본 조건(N=4096, TILE_DIM=32) 배속: {main_speedup:.2f}x")
        if main_speedup < MIN_SPEEDUP:
            print(f"  다만 배속이 {MIN_SPEEDUP}x에 못 미친다. 정답이긴 하지만 타일링 이득이")
            print("  거의 없다는 뜻이므로, 보고서에서 그 이유를 함께 다뤄라.")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
