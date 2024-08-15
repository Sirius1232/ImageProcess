# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        CLAHE_FPGA.py
# Descriptions:     限制对比度的自适应直方图均衡化（硬件思路验证）
# -----------------------------------------README-----------------------------------------
# 对硬件设计思路的验证，执行效率很低。
#
# 可以对RGB彩图做处理：先转换到HSV空间，对V通道做处理，然后再还原回RGB。
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def pre_calculate(loc, factor, src_shape):
    num = [0, 0, 0, 0]
    i, j = loc
    src_h, src_w = src_shape
    factor_h, factor_w = factor
    block_i = i // factor_h
    block_j = j // factor_w
    flag_i = 1 if (i % factor_h < factor_h // 2) else 0
    flag_j = 1 if (j % factor_w < factor_w // 2) else 0

    num_i = 0 if (block_i == 0) else block_i - flag_i
    num_j = 0 if (block_j == 0) else block_j - flag_j
    flag_l_r = (block_j == 0 and flag_j == 1) or (block_j == src_w - 1 and flag_j == 0)
    flag_u_d = (block_i == 0 and flag_i == 1) or (block_i == src_h - 1 and flag_i == 0)

    num[0] = num_i * src_w + num_j
    num[1] = num[0] if (flag_l_r) else num[0] + 1
    num[2] = num[0] if (flag_u_d) else num[0] + src_w
    num[3] = num[1] if (flag_u_d) else num[1] + src_w
    u = j - (num_j * factor_w + factor_w // 2)
    v = i - (num_i * factor_h + factor_h // 2)
    return num, u, v


def ave(weight, factor, src_value):
    u, v = weight
    factor_h, factor_w = factor
    tmp_mul = [0, 0]
    tmp_mul[0] = ((factor_h - v) * src_value[0] + v * src_value[2]) // 256
    tmp_mul[1] = ((factor_h - v) * src_value[1] + v * src_value[3]) // 256
    dst = (factor_w - u) * tmp_mul[0] + u * tmp_mul[1]
    return dst


def hsv2bgr(bgr: np.ndarray, new_V: np.ndarray):
    tmp = bgr.astype(np.uint32) * new_V.astype(np.uint32)[:, :, None]
    m = bgr.astype(np.uint32).max(axis=-1)[:, :, None]
    m[m == 0] = 1  # 避免除零
    dst = tmp / m
    dst = dst.clip(0, 255).astype(np.uint8)
    return dst


def CLAHE(img: np.ndarray, block: int = 8):
    gray = img.max(axis=-1)
    height, width = gray.shape
    block_h = height // block
    block_w = width // block
    TOTAL = block_h * block_w
    LIMIT = 4 * TOTAL // 256
    SCALE = TOTAL * TOTAL // 255 // 128 // 256

    pdf = np.zeros((block * block, 256), dtype=int)
    cdf = np.zeros((block * block, 256))

    # 统计各块直方图分布
    for i in range(height):
        for j in range(width):
            block_i = i // block_h
            block_j = j // block_w
            num = block_i * block + block_j
            index = gray[i][j]
            pdf[num][index] += 1

    # 限制对比度，计算各块累积分布直方图
    for i in range(block):
        for j in range(block):
            num = i * block + j
            # 裁剪操作
            steal = 0
            for k in range(256):
                if pdf[num][k] > LIMIT:
                    steal += pdf[num][k] - LIMIT
                    pdf[num][k] = LIMIT
            # print(steal)
            bonus = steal // 256
            # 计算累积分布直方图
            for k in range(256):
                pdf[num][k] += bonus
            for k in range(256):
                if k == 0:
                    cdf[num][k] = pdf[num][k]
                else:
                    cdf[num][k] = cdf[num][k - 1] + pdf[num][k]
    cdf = cdf // 128

    print("cdf done!")

    new_V = np.ndarray(gray.shape)
    tmp_cdf = [0, 0, 0, 0]
    num = [0, 0, 0, 0]
    # 均衡化
    for i in range(height):
        for j in range(width):
            num, u, v = pre_calculate((i, j), (height // 8, width // 8), (8, 8))
            tmp_cdf[0] = cdf[num[0]][gray[i][j]]
            tmp_cdf[1] = cdf[num[1]][gray[i][j]]
            tmp_cdf[2] = cdf[num[2]][gray[i][j]]
            tmp_cdf[3] = cdf[num[3]][gray[i][j]]
            new_V[i][j] = ave((u, v), (height // 8, width // 8), tmp_cdf)
    new_V = (new_V // SCALE).astype(np.uint8)
    dst = hsv2bgr(img, new_V)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[4:1084, 8:1928]

    start = time()
    dst = CLAHE(src)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    cv2.waitKey()
    cv2.destroyAllWindows()
