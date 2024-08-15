# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        BiLinear_FPGA.py
# Descriptions:     双线性插值算法实现图像缩放（硬件思路验证）
# -----------------------------------------README-----------------------------------------
# 对硬件设计思路的验证，执行效率很低。
# 
# 对RGB三个通道分别做双线性插值。
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def bi_linear(src: np.ndarray, scale: float) -> np.ndarray:
    th, tw = 1080, 1920  # int(scale * src.shape[0]), int(scale * src.shape[1])
    dst = np.zeros((th, tw, 3))
    scale_h = int(8 * scale)
    scale_w = int(8 * scale)
    addr = [0, 0, 0, 0]
    tmp_mul = [0, 0]
    SCALE = scale_h * scale_w // 256
    test = set()
    for i in range(th):
        for j in range(tw):
            new_i = 8 * i
            new_j = 8 * j
            block_i = new_i // scale_h
            block_j = new_j // scale_w
            flag_i = 1 if (new_i % scale_h < scale_h // 2) else 0
            flag_j = 1 if (new_j % scale_w < scale_w // 2) else 0

            num_i = 0 if (block_i == 0) else block_i - flag_i
            num_j = 0 if (block_j == 0) else block_j - flag_j
            flag_u_d = (block_i == 0 and flag_i == 1) or (block_i == src.shape[0] - 1 and flag_i == 0)
            flag_l_r = (block_j == 0 and flag_j == 1) or (block_j == src.shape[1] - 1 and flag_j == 0)

            addr[0] = (num_i, num_j)
            addr[1] = (addr[0][0], addr[0][1] if (flag_l_r) else addr[0][1] + 1)
            addr[2] = (addr[0][0] if (flag_u_d) else addr[0][0] + 1, addr[0][1])
            addr[3] = (addr[1][0] if (flag_u_d) else addr[1][0] + 1, addr[1][1])
            u = new_j - (addr[0][1] * scale_w + scale_w // 2)
            v = new_i - (addr[0][0] * scale_h + scale_h // 2)

            tmp_src_0 = src[addr[0][0]][addr[0][1]].astype(np.int32)
            tmp_src_1 = src[addr[1][0]][addr[1][1]].astype(np.int32)
            tmp_src_2 = src[addr[2][0]][addr[2][1]].astype(np.int32)
            tmp_src_3 = src[addr[3][0]][addr[3][1]].astype(np.int32)
            # print(tmp_src_0, tmp_src_1, tmp_src_2, tmp_src_3)
            tmp_mul[0] = (scale_h - v) * tmp_src_0 + v * tmp_src_2
            tmp_mul[1] = (scale_h - v) * tmp_src_1 + v * tmp_src_3
            tmp = (scale_w - u) * (tmp_mul[0] // 256) + u * (tmp_mul[1] // 256)
            dst[i][j] = tmp // SCALE
            test.add(num_i)
    dst = dst.astype(np.uint8)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[273:813, 487:1447]
    scale = 2

    start = time()
    dst = bi_linear(src, scale)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    while True:
        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):  # 按下q键，程序退出
            break
    cv2.destroyAllWindows()  # 释放并销毁窗口
