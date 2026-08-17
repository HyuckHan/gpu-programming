# 저장소 루트 Makefile — 배포 zip 만들기
#
#   make dist          labs/ 전부를 dist/*.zip 으로 묶는다
#   make dist LAB=lab06-tiled-matmul   하나만 묶는다
#   make clean         dist/ 를 지운다
#
# solutions/ 는 zip 에 절대 들어가지 않는다. 아래 stage 단계가 labs/ 에서만
# 파일을 복사하고, 마지막에 zip 안을 다시 검사한다.
#
# 예외가 하나 있다. lab08 은 프로파일링만 하는 랩이라 완성된 커널이 있어야 한다.
# lab06 의 TODO 를 못 채운 학생도 실습을 할 수 있어야 하므로 lab06 정답본을
# matmul.cu 라는 이름으로 넣는다. lab08 은 10주차라 lab06 제출이 이미 끝난
# 뒤이고, 타일드 커널 완성본은 강의 슬라이드에도 있다.
#
# 랩 간 의존 파일(위 lab08 의 matmul.cu, lab04 의 vecadd.cu, lab09 의 pgm.h)은
# deps.sh 에만 적는다. 이 Makefile 은 거기 있는 copy_lab_deps 를 부른다.

# deps.sh 의 copy_lab_deps 가 bash 문법을 쓴다
SHELL := /bin/bash

LABS  := $(notdir $(wildcard labs/lab*))
DIST  := dist
STAGE := $(DIST)/.stage

# 확장자로만 복사한다. 빌드 산출물(확장자 없는 실행 파일)과 out.pgm 이 딸려
# 들어가지 않게 하려는 것이다.
# 따옴표가 필요하다. 없으면 셸이 저장소 루트에서 먼저 글롭을 펼쳐 버린다.
SRC_EXT := "*.cu" "*.c" "*.h" "*.cuh" "*.py" "*.sh" "*.txt"

MAINFONT ?= Noto Sans CJK KR 
MONOFONT ?= D2Coding

.PHONY: help dist clean notes

help:
	@echo "저장소 루트"
	@echo ""
	@echo "  make dist                          labs/ 전부를 dist/*.zip 으로 묶는다"
	@echo "  make dist LAB=lab06-tiled-matmul   하나만 묶는다"
	@echo "  make clean                         dist/ 를 지운다"
	@echo ""
	@echo "각 랩의 빌드는 그 디렉터리에서 make 한다. 루트에서 빌드하지 않는다."

dist:
	@rm -rf $(STAGE)
	@mkdir -p $(DIST)
	@set -e; . ./deps.sh; \
	for lab in $(if $(LAB),$(LAB),$(LABS)); do \
	  if [ ! -d "labs/$$lab" ]; then echo "labs/$$lab 이 없다" >&2; exit 1; fi; \
	  stage="$(STAGE)/$$lab"; \
	  mkdir -p "$$stage"; \
	  cp "labs/$$lab/Makefile" "$$stage/"; \
	  if [ -f "labs/$$lab/README.md" ]; then cp "labs/$$lab/README.md" "$$stage/"; fi; \
	  for pat in $(SRC_EXT); do \
	    for f in labs/$$lab/$$pat; do \
	      if [ -f "$$f" ]; then cp "$$f" "$$stage/"; fi; \
	    done; \
	  done; \
	  copy_lab_deps "$(CURDIR)" "$$lab" "$$stage"; \
	  rm -f "$(DIST)/$$lab.zip"; \
	  (cd "$(STAGE)" && zip -qr "../$$lab.zip" "$$lab"); \
	  if unzip -l "$(DIST)/$$lab.zip" | grep -qi "solution"; then \
	    echo "!! $$lab.zip 에 정답이 들어갔다" >&2; exit 1; \
	  fi; \
	  echo "  $(DIST)/$$lab.zip"; \
	done
	@rm -rf $(STAGE)

notes:
	@mkdir -p dist
	@for d in labs/*/; do \
	  n=$$(basename $$d); \
	  [ -f $$d/README.md ] || continue; \
	  pandoc $$d/README.md -o dist/$$n.pdf \
	    --pdf-engine=xelatex \
	    --highlight-style=monochrome \
	    -V mainfont="$(MAINFONT)" -V monofont="$(MONOFONT)" \
	    -V geometry:margin=25mm -V fontsize=11pt \
	    -V header-includes='\renewcommand{\arraystretch}{2}' \
	  && echo "  $$n.pdf" || echo "  !! $$n 실패"; \
	done

clean:
	rm -rf $(DIST)
