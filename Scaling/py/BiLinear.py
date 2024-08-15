# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        BiLinear.py
# Descriptions:     双线性插值算法实现图像缩放
# -----------------------------------------README-----------------------------------------
# 对RGB三个通道分别做双线性插值。
# 
# 坐标映射策略：将目标图像四个角的像素点坐标映射到源图像的四个角上。
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def bi_linear(src: np.ndarray, target_size) -> np.ndarray:
    dst_h, dst_w = target_size[0], target_size[1]
    dst = np.zeros(target_size)
    src_h = src.shape[0]
    src_w = src.shape[1]
    addr = [0, 0, 0, 0]
    tmp_mul = [0, 0]
    for i in range(dst_h):
        for j in range(dst_w):
            src_x = i * (src_h - 1) / (dst_h - 1)
            src_y = j * (src_w - 1) / (dst_w - 1)
            num_i = int(src_x)
            num_j = int(src_y)
            u = src_y - num_j
            v = src_x - num_i
            flag_u_d = (i == 0) or (i == dst_h - 1)
            flag_l_r = (j == 0) or (j == dst_w - 1)
            addr[0] = (num_i, num_j)
            addr[1] = (addr[0][0], addr[0][1] if (flag_l_r) else addr[0][1] + 1)
            addr[2] = (addr[0][0] if (flag_u_d) else addr[0][0] + 1, addr[0][1])
            addr[3] = (addr[1][0] if (flag_u_d) else addr[1][0] + 1, addr[1][1])
            try:
                tmp_src_0 = src[addr[0][0]][addr[0][1]].astype(np.int32)
                tmp_src_1 = src[addr[1][0]][addr[1][1]].astype(np.int32)
                tmp_src_2 = src[addr[2][0]][addr[2][1]].astype(np.int32)
                tmp_src_3 = src[addr[3][0]][addr[3][1]].astype(np.int32)
            except Exception as e:
                print(addr)
                raise e
            tmp_mul[0] = (1 - v) * tmp_src_0 + v * tmp_src_2
            tmp_mul[1] = (1 - v) * tmp_src_1 + v * tmp_src_3
            dst[i][j] = (1 - u) * tmp_mul[0] + u * tmp_mul[1]
    dst = dst.astype(np.uint8)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[273:813, 487:1447]
    scale = 2

    start = time()
    dst = bi_linear(src, (1080, 1920, 3))
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    while True:
        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):  # 按下q键，程序退出
            break
    cv2.destroyAllWindows()  # 释放并销毁窗口
