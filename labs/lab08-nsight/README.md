# lab08 — Nsight Compute

**목표:** 커널의 병목이 연산인지 메모리인지 도구로 판정한다.

이 랩에는 **새로 만드는 커널이 없다.** `matmul.cu`는 lab06에서 완성한 그 커널이고
정답 상태로 들어 있다. 이번 주에 하는 일은 코드를 고치는 것이 아니라
**이미 있는 코드를 도구로 들여다보는 것**이다.

lab06까지는 "몇 ms 걸렸다"만 알았다. 왜 그만큼 걸렸는지는 몰랐다.
`ncu`는 그것을 알려 준다.

## 1. 준비

```
make
ncu --version
```

`ncu`는 CUDA 툴킷에 함께 들어 있다. **따로 설치할 필요가 없다.**
버전이 찍히면 준비가 끝난 것이다. 오류가 나면 7절로 간다.

Makefile이 `-lineinfo`로 빌드한다. 이 플래그가 없으면 `ncu`가 측정값을
소스 줄과 연결하지 못한다. lab03에서 `compute-sanitizer`에 줄 번호를
얻으려고 붙였던 것과 같은 플래그다.

### 문제 크기를 두 가지로 잰다

`ncu`는 카운터를 모으려고 **커널을 여러 번 다시 실행한다(replay).**
출력에 `7 passes`라고 나오는 것이 그것이다. 그래서 프로파일링은 그냥
실행하는 것보다 오래 걸린다. 이 랩의 크기에서는 한 번에 3~5초쯤이다.

이 실습은 `N=1024`와 `N=4096` **둘 다** 잰다. 두 크기의 차이가 이 랩의
핵심이기 때문이다.

- `N=1024` — 행렬 3개가 12MB다. **L2 캐시 안에 다 들어간다.**
- `N=4096` — 행렬 3개가 201MB다. **L2를 한참 넘는다.**

lab06에서 두 크기의 배속이 달랐던 이유를 여기서 숫자로 확인하게 된다.

## 2. 세 지표

전체 metric은 수백 개다. 다 훑으면 시간만 쓰고 아무 결론도 안 나온다.
**병목이 어느 쪽인지 가르는 데 필요한 것은 셋뿐이다.**

| metric | 뜻 |
|---|---|
| `sm__throughput.avg.pct_of_peak_sustained_elapsed` | 연산 유닛 사용률 |
| `gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed` | DRAM 대역폭 사용률 |
| `sm__warps_active.avg.pct_of_peak_sustained_active` | achieved occupancy |

앞의 두 값 중 **어느 쪽이 100%에 가까운가로 병목이 갈린다.**

- 연산 사용률이 높다 → 연산에 묶여 있다(compute bound)
- DRAM 사용률이 높다 → 메모리에 묶여 있다(memory bound)
- **둘 다 낮다** → 어느 쪽도 포화시키지 못하고 있다. 지연을 못 숨기고 있다는 뜻이다

세 번째 값은 병목을 가르지 않는다. 위의 두 값을 해석할 때 곁들여 보는 것이다.
lab04에서 계산한 이론 occupancy와 견주어 보라.

> **주의.** `sm__throughput`은 이름과 달리 FP32 연산기만 보는 값이 아니다.
> SM 안의 여러 유닛(연산기, load/store 유닛, 공유 메모리 등) 중
> **가장 많이 쓰인 것**의 사용률이다. 그래서 이 값이 높다고 곧바로
> "계산이 많다"로 읽으면 안 된다. 무엇이 그 값을 밀어 올렸는지는
> 5절의 `--set basic`이 쪼개서 보여 준다.

## 3. naive 커널 프로파일링

```
ncu --metrics \
sm__throughput.avg.pct_of_peak_sustained_elapsed,\
gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed,\
sm__warps_active.avg.pct_of_peak_sustained_active \
--kernel-name mm_kernel --launch-count 1 ./matmul 1024 16
```

`--kernel-name`은 볼 커널만 고르는 것이고, `--launch-count 1`은 그중 첫
실행 한 번만 재라는 뜻이다. 프로그램이 커널을 예열용과 측정용으로 두 번씩
부르기 때문에 이것을 주지 않으면 같은 내용이 두 번 나온다.

실제 출력에서 마지막 표만 옮기면 이렇다.

```
  mm_kernel(float *, float *, float *, unsigned int) (64, 64, 1)x(16, 16, 1), Context 1, Stream 7, Device 0, CC 8.9
    Section: Command line profiler metrics
    ------------------------------------------------------ ----------- ------------
    Metric Name                                            Metric Unit Metric Value
    ------------------------------------------------------ ----------- ------------
    gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed           %         1.76
    sm__throughput.avg.pct_of_peak_sustained_elapsed                 %        93.25
    sm__warps_active.avg.pct_of_peak_sustained_active                %        98.10
    ------------------------------------------------------ ----------- ------------
```

`N=4096`으로도 한 번 돌린다. 끝의 인자만 바꾼다.

```
... --kernel-name mm_kernel --launch-count 1 ./matmul 4096 16
```

```
    gpu__dram_throughput.avg.pct_of_peak_sustained_elapsed           %        44.02
    sm__throughput.avg.pct_of_peak_sustained_elapsed                 %        76.28
    sm__warps_active.avg.pct_of_peak_sustained_active                %        99.87
```

**같은 커널인데 DRAM 사용률이 1.76%에서 44%로 뛴다.** 왜 그런지가 토론 문제 1번이다.

전체 출력은 `sample-output.txt`에 들어 있다. 위 숫자는 개발 PC(RTX 4060 Ti)에서
얻은 것이라 실습실 PC에서는 조금 다르게 나온다. 자기 화면의 값을 적어라.

## 4. tiled 커널 프로파일링

**`--kernel-name`만 바꾼다.** 나머지는 그대로다.

```
... --kernel-name mm_tiled_kernel --launch-count 1 ./matmul 1024 16
```

`N=1024`와 `N=4096` 둘 다 돌린다.

## 5. 표를 채운다

네 줄 모두 채운다.

| 커널 | N | 연산 사용률 | DRAM 사용률 | occupancy |
|---|---|---|---|---|
| naive | 1024 | | | |
| tiled | 1024 | | | |
| naive | 4096 | | | |
| tiled | 4096 | | | |

### 무엇이 사용률을 밀어 올렸는지 쪼개 본다

세 지표만으로는 `sm__throughput`이 왜 높은지 알 수 없다. 요약 화면을 한 번 본다.

```
ncu --set basic ./matmul 1024 16
```

`GPU Speed Of Light Throughput` 절에 이런 줄들이 있다.

```
    Memory Throughput                   %        93.25
    DRAM Throughput                     %         6.10
    Duration                      msecond         1.84
    L1/TEX Cache Throughput             %        93.79
    L2 Cache Throughput                 %        22.07
    Compute (SM) Throughput             %        93.25
```

**L1/TEX가 93.79%다.** 3절의 `sm__throughput` 93.25%를 밀어 올린 것이
연산기가 아니라 캐시 접근이었다는 뜻이다. 이 줄들도 표에 함께 적어 두면
토론 문제 1번을 답하기 쉬워진다.

`--set basic`은 커널마다 여러 절을 찍고 예열·측정 네 번의 실행이 모두 나오므로
출력이 길다. 위 여섯 줄만 보면 된다.

## 6. 토론 문제

**1.** `N=1024`에서 두 커널 모두 DRAM 사용률이 몇 %인가? 연산 사용률은?
**두 값이 이렇게 벌어져 있다면 병목은 어디에 있는가?**
5절의 `L1/TEX Cache Throughput`과 `L2 Cache Throughput`을 함께 보라.
행렬 3개가 12MB인데 이 GPU의 L2가 몇 MB인지 확인하고, DRAM이 왜
거의 놀고 있는지 설명하라.

**2.** `N`을 1024에서 4096으로 키우면 DRAM 사용률이 어떻게 움직이는가?
커널 코드는 한 줄도 바뀌지 않았다. 무엇이 바뀐 것인가?
lab06 보고서에서 두 `N`의 배속이 달랐던 것과 연결해 설명하라.

**3.** naive에서 tiled로 바꾸면 두 사용률이 어떻게 이동하는가?
`N=4096`에서 tiled는 naive보다 빠른데 DRAM 사용률은 **더 높게** 나온다.
사용률은 "총량"이 아니라 "단위 시간당 비율"이라는 점을 생각해 보라.
같은 양의 데이터를 더 짧은 시간에 옮기면 이 값은 어느 쪽으로 움직이는가?

**4.** lab06에서 잰 실행 시간(ms, GFLOP/s)과 여기 숫자는 어떻게 연결되는가?
tiled가 1.3~1.6배 빠른 것이 위 표의 어느 값의 변화로 설명되는가?

**5.** occupancy가 높은 쪽이 항상 빠른가?
위 표에서 두 커널의 occupancy를 비교해 보라. 거의 같은가, 다른가?
lab04의 occupancy 표와 lab06의 `TILE_DIM` 8/16/32 비교를 함께 놓고,
occupancy가 성능에 대해 무엇을 말해 주고 무엇을 말해 주지 않는지 적어라.

## 7. 문제 해결

### `ERR_NVGPUCTRPERM`

```
==ERROR== ERR_NVGPUCTRPERM - The user does not have permission to access
NVIDIA GPU Performance Counters on the target device.
```

성능 카운터는 기본적으로 관리자만 읽을 수 있다. **실습실 PC는 모든 사용자가
접근하도록 이미 설정되어 있으므로 이 오류가 나지 않아야 한다.** 났다면 조교에게
알려라.

개인 PC에서 돌린다면 직접 풀어야 한다.

- **Windows** — NVIDIA 제어판 → 데스크톱 → 개발자 설정 사용 →
  "개발자 설정 관리" → *Enable NVIDIA GPU performance counters for all users*.
  설정 후 재부팅한다.
- **Linux / WSL2** — `/etc/modprobe.d/`에 `NVreg_RestrictProfilingToAdminUsers=0`
  옵션을 넣고 재부팅하거나, `sudo ncu ...`로 실행한다.

자세한 것은 오류 메시지에 함께 나오는 NVIDIA 문서 링크를 따라가면 된다.

### 커널 이름이 안 잡힌다

`--kernel-name mm_tiled_kernel`을 줬는데 아무것도 안 나온다면,
tiled 커널이 template이라 실제 이름이 길어서 그렇다. 부분 문자열로 찾으므로
`mm_tiled_kernel`만으로 잡히는 것이 정상이지만, 안 되면 `--kernel-name-base demangled`
를 붙이거나 `--kernel-name regex:mm_tiled`로 바꾼다.

### 너무 오래 걸린다

`--launch-count 1`을 빠뜨리지 않았는지 본다. 이것이 없으면 프로그램이 부르는
모든 실행을 다 프로파일링한다. `--set full`은 metric을 전부 모으므로
훨씬 오래 걸린다. 이 실습에서는 쓰지 않는다.

## 제출

- 5절 표 (네 줄 모두, `--set basic`의 L1/L2 줄을 함께 적으면 더 좋다)
- 토론 문제 1~5 답변

**제출: 필수**

전체 11개 실습 중 9개 이상 제출해야 P 를 받을 수 있다.

## 참고

Makefile 이 `-arch=native` 로 빌드하므로 꽂혀 있는 GPU 에 맞춰 자동으로
컴파일된다. 다른 PC 에서도 `make` 만 치면 된다.

`matmul.cu`는 lab06 의 완성본이다. lab06 을 못 채웠더라도 이번 주 실습은
그대로 할 수 있다. 채우지 못했다면 이 파일을 lab06 의 답으로 삼아 읽어 보라.
