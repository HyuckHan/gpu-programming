# GPU 프로그래밍 실습

동덕여대 2026-2학기. 컴퓨터공학 4학년 전공선택, P/F.

주차 번호는 **이 표에만** 둔다. 각 랩의 README 는 랩 번호로만 서로를 가리키므로,
일정이 밀리면 이 표만 고치면 된다.

## 주차 매핑

| 주 | 강의 | 랩 |
|---|---|---|
| 1 | 오리엔테이션 | — |
| 2 | Ch01 GPU 개요 | lab01 환경 확인 + C 워밍업 *(집계 제외)* |
| 3 | Ch02 이종 데이터 병렬 컴퓨팅 | lab02 벡터 덧셈 |
| 4 | Ch03 다차원 그리드와 데이터 | lab03 blur 와 경계 조건 |
| 5 | Ch04 계산 아키텍처와 스케줄링 | lab04 워프와 occupancy |
| 6 | Ch05 메모리 아키텍처와 데이터 지역성 | lab05 행렬곱 (naive) |
| 7 | Ch05 타일링 | lab06 공유 메모리 타일링 |
| 8 | 중간고사 | — |
| 9 | Ch06 성능 고려사항 | lab07 coalescing 과 coarsening |
| 10 | 프로파일링 도구 | lab08 Nsight Compute |
| 11 | Ch07 컨볼루션 | lab09 컨볼루션과 상수 메모리 |
| 12 | Ch09 병렬 히스토그램 | lab10 히스토그램과 데이터 경쟁 |
| 13 | Ch10 리덕션 | lab11 리덕션 최적화 사다리 |
| 14 | Ch11 Prefix Sum (Scan) Part 1 | lab12 스캔 (Kogge-Stone) |
| 15 | 정리 | lab13 scan 변형 *(준비 중)* |
| 16 | 기말고사 | — |

## 이수 조건

전체 11개 실습 중 9개 이상 제출해야 P 를 받을 수 있다.
제출 여부만 확인하고 점수를 매기지 않는다. 각 랩의 제출물은 해당 README 에 있다.

집계 대상은 lab02, lab03, lab04, lab05, lab06, lab07, lab08, lab09, lab10, lab11,
lab12 열한 개다. **lab01 만 집계에 들어가지 않는다.** 학기 첫 진단용이기 때문이다.
lab13 을 나중에 넣게 되면 이 숫자를 다시 맞춰야 한다.

## 저장소 구성

| 경로 | 내용 |
|---|---|
| `labs/` | 랩별 실습 자료. 배포는 LMS zip 으로 별도 수행한다 |
| `common/common.cuh` | 모든 랩이 공유하는 하니스 (CUDA_CHECK, 타이머, 비교 헬퍼) |
| `extracted/` | 강의 덱에서 뽑아낸 코드 조각. 랩 코드의 변수명 기준 |
| `extract_code.py` | pptx 에서 코드를 추출하는 스크립트 |
| `slides/` | 강의 덱. 제3자 자료라 추적하지 않는다 |
| `solutions/` | 각 랩의 `// TODO:` 를 채운 정답본. 배포 zip 에는 들어가지 않는다 |
| `check_solutions.sh` | 정답본으로 전 랩을 빌드·실행한다 |
| `Makefile` | `make dist` — 배포 zip 을 만든다 |

## 빌드

각 랩 디렉터리에서 `make` 하나면 된다. nvcc 플래그는 Makefile 이 관리한다.
모든 랩이 `-arch=native` 로 빌드하므로 꽂혀 있는 GPU 에 맞춰 컴파일된다.
폴백은 두지 않았다. 툴킷이 그 GPU 를 모르면 빌드가 실패하는 것이 옳다.
조용히 다른 아키텍처로 빌드되면 실행 시점에 `no kernel image is available` 이
뜨고 원인을 찾기 어렵다.

> sm_120(RTX 50 시리즈)은 CUDA 12.8 이상이 있어야 컴파일된다.
> 현재 툴킷이 12.4 라면 그 PC 에서는 툴킷을 먼저 올려야 한다.

`common.cuh` 는 저장소에서는 `common/` 에, 배포 zip 에서는 랩 디렉터리에 함께
들어간다. Makefile 이 양쪽을 다 찾으므로 소스의 include 는 `"common.cuh"` 하나다.

`make help` 로 각 랩에서 쓸 수 있는 명령을 볼 수 있다.
`make test` 는 `verify.py` 를 돌려 제출 전 자체 점검을 한다.

## 배포

```
make dist                          # dist/*.zip
make dist LAB=lab06-tiled-matmul   # 하나만
```

zip 하나가 랩 하나다. 학생은 풀고 `make` 만 치면 된다.
`common.cuh` 는 lab01 을 뺀 모든 zip 에 복사해 넣는다. 학생 쪽에는
`common/` 디렉터리가 없기 때문이다.

일부 랩은 다른 랩의 파일도 쓴다. 저장소에는 중복 보관하지 않고
zip 을 만들 때 복사해 넣는다.

| 랩 | 함께 넣을 파일 |
|---|---|
| lab04 | lab02 의 `vecadd.cu` |
| lab08 | `solutions/lab06/skeleton.cu` → `matmul.cu` |
| lab09 | lab03 의 `pgm.h` |

`solutions/` 는 zip 에 절대 들어가지 않는다. `make dist` 가 zip 을 만든 뒤
안을 한 번 더 검사하고, 흔적이 있으면 실패한다.

**lab08 만 예외다.** 프로파일링만 하는 랩이라 완성된 커널이 있어야 한다.
lab06 의 TODO 를 못 채운 학생도 실습을 할 수 있어야 하므로 lab06 정답본을
`matmul.cu` 라는 이름으로 넣는다. lab08 은 10주차라 lab06 제출이 이미 끝난
뒤이고, 타일드 커널 완성본은 강의 슬라이드에도 있다.

## 정답본

`solutions/<랩>/` 에 `// TODO:` 를 채운 파일이 원본과 같은 이름으로 들어 있다.
근거는 `extracted/` 의 슬라이드 코드다 (lab01 과 lab10 privatization 만 예외 —
슬라이드에 코드가 없어 직접 작성했다).

```
bash check_solutions.sh          # 전 랩
bash check_solutions.sh lab06    # 하나만
```

임시 디렉터리에 배포 zip 과 같은 구성을 만들고 정답본을 덮어써서 빌드·실행한다.
`labs/` 는 건드리지 않는다. `declared but never referenced` 경고가 뜨면
그 랩의 TODO 가 덜 채워진 것이다.

## 아직 배정하지 않은 것

- **Ch08 스텐실** — 덱과 추출 코드는 있으나 배정된 주가 없다
- **Ch11 Part 2 (Brent-Kung)** — 슬라이드는 두되 진도에서 뺐다.
  work efficiency 분석이 이 학생층에 비용 대비 효과가 낮다
- **lab14 전치 행렬곱** — CLAUDE.md 에 D 유형 과제로 언급되어 있으나
  현재 주차 배정에는 들어 있지 않다
