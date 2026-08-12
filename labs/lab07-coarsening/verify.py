#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

matmul.cu를 빌드하고 여러 조합으로 돌려서 coarse 커널의 검증 통과 여부를
판정한다. naive와 tiled는 이미 완성되어 있으므로 판정 대상이 아니다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, TILE_DIM, COARSE_FACTOR)
# N이 TILE_DIM*COARSE_FACTOR의 배수인 조합만 넣었다.
CONFIGS = [
    (1024, 16, 4),
    (1024,  8, 8),
    (2048, 32, 2),
    (4096, 16, 4),
]


def run(cmd, timeout=900):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def coarse_status(out):
    m = re.search(r"정확성:.*coarse=(\S+)", out)
    return m.group(1) if m else None


def main():
    print("=" * 60)
    print("lab07 coarsening — 자체 점검 (판정 대상: coarse 커널)")
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
    failed = []
    for N, tile, coarse in CONFIGS:
        label = f"  N={N:<5} TILE_DIM={tile:<3} COARSE_FACTOR={coarse:<2}"
        try:
            r = run([str(HERE / "matmul"), str(N), str(tile), str(coarse)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append((N, tile, coarse))
            continue

        status = coarse_status(r.stdout)
        if status is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:400])
            failed.append((N, tile, coarse))
            continue

        print(f"{label} coarse {status}")
        if status != "PASS":
            mismatch = re.search(r"첫 불일치: .*", r.stdout)
            if mismatch:
                print("   ", mismatch.group(0).strip())
            failed.append((N, tile, coarse))

    print("\n" + "=" * 60)
    if failed:
        print("결과: 실패 " + ", ".join(f"(N={n}, T={t}, C={c})" for n, t, c in failed))
        src = (HERE / "matmul.cu").read_text(encoding="utf-8")
        if "TODO: 슬라이드 22" in src:
            print("matmul.cu의 mm_tiled_coarse_kernel 에 아직 TODO가 남아 있다.")
            print("슬라이드 22를 옮겨 채워라.")
        else:
            print("점검할 것:")
            print("  • colStart 에 blockDim.x*COARSE_FACTOR 를 곱했는가")
            print("  • A 타일 적재가 c 루프 바깥에 있는가")
            print("  • __syncthreads() 가 c 루프 안에 두 번 들어 있는가")
            print("    (B 타일 적재 뒤 한 번, 계산 뒤 한 번)")
        return 1

    print(f"결과: 전부 통과 ({len(CONFIGS)}/{len(CONFIGS)})")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
