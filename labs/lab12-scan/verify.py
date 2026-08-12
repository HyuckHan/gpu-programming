#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

scan 을 빌드하고 돌려서 shared 커널의 검증 통과 여부를 판정한다.
race 는 틀리는 것이 정상이라 판정 대상이 아니고,
double 은 완성 제공된 것이며, exclusive 는 선택 과제라 판정에 넣지 않는다.
표준 라이브러리만 쓴다.
"""
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

SIZES = [1 << 20, 1 << 16, 2048]


def run(cmd, timeout=600):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def kernel_line(out, name):
    m = re.search(rf"^{name}\s*:\s*(.+)$", out, re.MULTILINE)
    return m.group(1).strip() if m else None


def main():
    print("=" * 62)
    print("lab12 스캔 — 자체 점검 (판정 대상: shared 커널)")
    print("=" * 62)

    print("\n[1/2] 빌드")
    build = run(["make", "scan"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip()[:800])
        return 1
    print("  OK")

    print("\n[2/2] 실행")
    failed = []
    for N in SIZES:
        label = f"  N={N:<9}"
        try:
            r = run([str(HERE / "scan"), str(N)])
        except subprocess.TimeoutExpired:
            print(f"{label} 시간 초과")
            failed.append(N)
            continue

        line = kernel_line(r.stdout, "shared")
        if line is None:
            print(f"{label} 실행 실패 (rc={r.returncode})")
            print("   ", (r.stderr.strip() or r.stdout.strip())[:300])
            failed.append(N)
            continue

        print(f"{label} shared : {line}")
        if "PASS" not in line:
            failed.append(N)

    print("\n" + "=" * 62)
    if failed:
        print("결과: 실패 " + ", ".join(f"N={n}" for n in failed))
        src = (HERE / "scan.cu").read_text(encoding="utf-8")
        if "TODO: 슬라이드 13" in src:
            print("scan.cu 의 scan_shared_kernel 에 아직 TODO 가 남아 있다.")
            print("슬라이드 13의 루프 본문을 옮겨 채워라.")
        else:
            print("점검할 것:")
            print("  • float v 로 읽기와 쓰기를 갈라 놓았는가")
            print("  • 루프 한 번에 __syncthreads() 를 두 번 넣었는가")
            print("    (읽은 뒤 한 번, 쓴 뒤 한 번)")
            print("  • buffer_s[threadIdx.x - stride] 로 읽는가")
            print("    전역 버전의 output[i - stride] 를 그대로 옮기면 안 된다")
        return 1

    print(f"결과: 전부 통과 ({len(SIZES)}/{len(SIZES)})")
    print("제출해도 된다. exclusive 는 선택 과제라 점검에 넣지 않는다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
