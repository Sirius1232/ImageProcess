# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        CLAHE.py
# Descriptions:     限制对比度的自适应直方图均衡化
# -----------------------------------------README-----------------------------------------
# 这个代码要求图像的h和w必须是`block*2`的整数倍
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def CLAHE(img: np.ndarray, block: int = 8):
    height, width = img.shape
    block_w = width // block
    block_h = height // block

    pdf = np.zeros((block * block, 256), dtype=int)
    cdf = np.zeros((block * block, 256))

    for i in range(block):
        for j in range(block):
            num = j + block * i
            total = block_w * block_h
            for ii in range(i * block_h, i * block_h + block_h):
                for jj in range(j * block_w, j * block_w + block_w):
                    index = img[ii][jj]
                    pdf[num][index] += 1
            # 裁剪操作
            average = block_w * block_h // 255
            limit = 4 * average
            steal = 0
            for k in range(256):
                if pdf[num][k] > limit:
                    steal += pdf[num][k] - limit
                    pdf[num][k] = limit
            bonus = steal // 256
            # 计算累积分布直方图
            for k in range(256):
                pdf[num][k] += bonus
                if k == 0:
                    cdf[num][k] = pdf[num][k] / total
                else:
                    cdf[num][k] = cdf[num][k - 1] + pdf[num][k] / total
    dst = np.ndarray(img.shape)

    for i in range(height):
        for j in range(width):
            if i <= block_h // 2 and j <= block_w // 2:  # 左上角
                num = 0
                dst[i][j] = cdf[num][img[i][j]]
            elif i <= block_h // 2 and j >= block * block_w - block_w // 2:  # 右上角
                num = block - 1
                dst[i][j] = cdf[num][img[i][j]]
            elif i >= block * block_h - block_h // 2 and j <= block_w // 2:  # 左下角
                num = block * (block - 1)
                dst[i][j] = cdf[num][img[i][j]]
            elif (
                i >= block * block_h - block_h // 2
                and j >= block * block_w - block_w // 2
            ):  # 右上角
                num = block * block - 1
                dst[i][j] = cdf[num][img[i][j]]
            elif i <= block_h // 2:  # 顶边
                num_i = 0
                num_j = (j - block_w // 2) // block_w
                num1 = num_i * block + num_j
                num2 = num1 + 1
                p = (j - (num_j * block_w + block_w / 2)) / (block_w)
                q = 1 - p
                dst[i][j] = q * cdf[num1][img[i][j]] + p * cdf[num2][img[i][j]]
            elif i >= (block * block_h - block_h // 2):  # 底边
                num_i = block - 1
                num_j = (j - block_w // 2) // block_w
                num1 = num_i * block + num_j
                num2 = num1 + 1
                p = (j - (num_j * block_w + block_w / 2)) / (block_w)
                q = 1 - p
                dst[i][j] = q * cdf[num1][img[i][j]] + p * cdf[num2][img[i][j]]
            elif j <= block_w // 2:  # 左边
                num_i = (i - block_h // 2) // block_h
                num_j = 0
                num1 = num_i * block + num_j
                num2 = num1 + block
                p = (i - (num_i * block_h + block_h / 2)) / block_h
                q = 1 - p
                dst[i][j] = q * cdf[num1][img[i][j]] + p * cdf[num2][img[i][j]]
            elif j >= (block * block_w - block_w // 2):  # 右边
                num_i = (i - block_h // 2) // block_h
                num_j = block - 1
                num1 = num_i * block + num_j
                num2 = num1 + block
                p = (i - (num_i * block_h + block_h / 2)) / block_h
                q = 1 - p
                dst[i][j] = q * cdf[num1][img[i][j]] + p * cdf[num2][img[i][j]]
            else:
                num_i = (i - block_h // 2) // block_h
                num_j = (j - block_w // 2) // block_w
                num1 = num_i * block + num_j
                num2 = num1 + 1
                num3 = num1 + block
                num4 = num2 + block
                u = (j - (num_j * block_w + block_w / 2)) / block_w
                v = (i - (num_i * block_h + block_h / 2)) / block_h
                dst[i][j] = (
                    (1 - u) * (1 - v) * cdf[num1][img[i][j]]
                    + (1 - u) * v * cdf[num3][img[i][j]]
                    + u * v * cdf[num4][img[i][j]]
                    + u * (1 - v) * cdf[num2][img[i][j]]
                )
    dst = (255 * dst).astype(np.uint8)
    print(dst)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[4:1084, 8:1928]
    gray = cv2.cvtColor(src, cv2.COLOR_BGR2GRAY)

    start = time()
    dst = CLAHE(gray)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", src)
    cv2.imshow("dst", dst)
    cv2.waitKey()
    cv2.destroyAllWindows()
