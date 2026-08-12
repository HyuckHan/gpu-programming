#!/usr/bin/env python3
"""
실습용 input.pgm 을 만든다. 표준 라이브러리만 쓴다.

    python3 make_input.py                 # 512x512, input.pgm 으로 저장
    python3 make_input.py 256 256
    python3 make_input.py 300 200 my.pgm

이 랩은 경계 조건이 주제다. 경계 처리 버그는 테두리 근처 픽셀만 바꾸므로,
그 자리가 평평한 색이면 버그가 있어도 값이 안 변해서 드러나지 않는다.
그래서 여기서 만드는 그림은 모든 무늬가 네 변에 걸치도록 배치되어 있고,
명암도 0과 255만 쓴다.
"""
import sys


def make_image(width, height):
    """네 변에 모두 뚜렷한 명암 경계가 닿는 그림을 만든다."""
    px = bytearray(width * height)

    # 오른쪽 변에 걸치는 원. 중심을 이미지 밖에 둔다.
    circle_x, circle_y = width, height // 2
    circle_r = min(width, height) // 3

    for y in range(height):
        for x in range(width):
            # 배경: 16픽셀 폭 사선. 네 변을 모두 가로지른다.
            v = 255 if (((x + y) + 6) // 16) % 2 else 0

            # 좌상단 모서리에 걸치는 흰 사각형
            if x < width // 4 and y < height // 5:
                v = 255

            # 오른쪽 변에 걸치는 검은 원
            if (x - circle_x) ** 2 + (y - circle_y) ** 2 < circle_r ** 2:
                v = 0

            # 아래쪽 변에 걸치는 흑백 빗살
            if y >= height - max(1, height // 8):
                v = 255 if (x // 12) % 2 else 0

            px[y * width + x] = v

    return px


def write_pgm(path, px, width, height):
    with open(path, "wb") as f:
        f.write(b"P5\n")
        f.write(b"# GPU programming lab w03 - blur test image\n")
        f.write(("%d %d\n255\n" % (width, height)).encode("ascii"))
        f.write(bytes(px))


def main():
    width  = int(sys.argv[1]) if len(sys.argv) > 1 else 512
    height = int(sys.argv[2]) if len(sys.argv) > 2 else 512
    path   = sys.argv[3] if len(sys.argv) > 3 else "input.pgm"

    if width < 1 or height < 1:
        print("width와 height는 1 이상이어야 한다")
        return 1

    write_pgm(path, make_image(width, height), width, height)
    print("%s 생성 (%d x %d, 8비트 회색조 P5)" % (path, width, height))
    print("blur 를 그냥 실행하면 이 파일을 입력으로 쓴다. 크기 인자는 무시된다.")
    print("자체 점검(verify.py)을 돌릴 때는 이 파일을 옮겨 두어라.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
