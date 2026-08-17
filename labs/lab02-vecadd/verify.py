#!/usr/bin/env python3
"""
제출 전 자체 점검 스크립트.

    python3 verify.py        (또는  make test)

vecadd 를 빌드하고 여러 (N, blockDim) 조합으로 돌려서 검증 통과 여부를 판정한다.
그다음 compute-sanitizer 로 범위 밖 접근이 0건인지 확인한다.

세 번째 단계가 이 랩에서는 없어서는 안 된다. 경계 검사를 빼먹은 커널도
검증은 PASS 로 통과한다. 범위 밖 쓰기가 cudaMalloc 이 잡아 둔 여유 공간에
떨어져서 배열 안의 값은 멀쩡하기 때문이다. 그 버그는 도구만 잡아낸다.

표준 라이브러리만 쓴다.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent

# (N, blockDim)
# 나누어떨어지지 않는 N과 딱 떨어지는 N을 함께 넣었다.
# 딱 떨어지는 쪽은 경계 검사를 잘못 쓴 경우(i <= N 같은 것)에 걸린다.
CONFIGS = [
    (9999999, 256),
    (9999999, 1024),
    (1000000, 32),
    (1048576, 256),
    (1, 64),
]

# compute-sanitizer 로 돌릴 조합. 남는 스레드가 생기는 것만 고른다.
# (1, 64) 는 블록 하나에 63개 스레드가 남으므로 경계 검사가 없으면 반드시 걸린다.
SANITIZE = [
    (9999999, 256),
    (1, 64),
]


def run(cmd, timeout=300):
    return subprocess.run(cmd, cwd=HERE, capture_output=True, text=True, timeout=timeout)


def sanitize(n, block):
    """compute-sanitizer 로 한 번 돌리고 (오류 개수, 출력) 을 돌려준다.
    개수를 못 읽으면 None 을 돌려준다."""
    r = run(["compute-sanitizer", "--print-limit", "3",
             str(HERE / "vecadd"), str(n), str(block)])
    out = r.stdout + r.stderr
    m = re.search(r"ERROR SUMMARY:\s*(\d+)\s*error", out)
    return (int(m.group(1)) if m else None), out


def main():
    print("=" * 60)
    print("lab02 벡터 덧셈 — 자체 점검")
    print("=" * 60)

    print("\n[1/3] 빌드")
    build = run(["make", "vecadd"])
    if build.returncode != 0:
        print("  빌드 실패\n")
        print(build.stderr.strip())
        print("\n  컴파일 오류부터 잡아야 한다. 괄호와 세미콜론 짝을 먼저 확인하라.")
        return 1
    print("  OK")

    print("\n[2/3] 실행")
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

    # 검증이 못 잡는 버그를 여기서 잡는다. 경계 검사가 없어도 위 검증은 통과한다.
    print("\n[3/3] compute-sanitizer — 범위 밖 접근이 0건이어야 한다")
    if shutil.which("compute-sanitizer") is None:
        print("  compute-sanitizer 를 찾지 못했다.")
        print("  CUDA 툴킷에 함께 들어 있다. /usr/local/cuda/bin 이 PATH 에 있는지 확인하라.")
        failed.append(("sanitizer", "없음"))
    else:
        for n, block in SANITIZE:
            label = f"  N={n:<9} blockDim={block:<5}"
            try:
                count, out = sanitize(n, block)
            except subprocess.TimeoutExpired:
                print(f"{label} 시간 초과")
                failed.append((n, block))
                continue
            if count is None:
                print(f"{label} 도구 실행 실패")
                print("   ", out.strip()[:400])
                failed.append((n, block))
                continue
            print(f"{label} 오류 {count}건")
            if count != 0:
                first = re.search(r"Invalid __global__ (\w+) of size (\d+)", out)
                thread = re.search(r"by thread \([^)]*\) in block \([^)]*\)", out)
                if first:
                    print("   ", first.group(0))
                if thread:
                    print("   ", thread.group(0))
                failed.append((n, block))

    print("\n" + "=" * 60)
    if failed:
        print(f"결과: 실패 {len(failed)}건  "
              + ", ".join(f"(N={n}, blockDim={b})" for n, b in failed))
        src = (HERE / "vecadd.cu").read_text(encoding="utf-8")
        # 파일 맨 위 안내문에도 "TODO"라는 낱말이 있다. 실제 표시만 골라 본다.
        if "TODO: 아래 한 줄" in src:
            print("vecadd.cu 에 아직 TODO 가 남아 있다. 커널의 그 한 줄을")
            print("i 가 배열 범위 안일 때만 실행되도록 감싸라 (슬라이드 21).")
        else:
            print("검증이 FAIL 이면 첫 불일치 위치를 보라.")
            print("  배열 끝 근처라면 경계 검사의 부등호를 확인하라 (i < N 인가).")
            print("범위 밖 접근이 남아 있으면 경계 검사가 감싸는 범위를 확인하라.")
        return 1

    print(f"결과: 전부 통과 (실행 {len(CONFIGS)}건, 도구 점검 {len(SANITIZE)}건)")
    print("제출해도 된다.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
