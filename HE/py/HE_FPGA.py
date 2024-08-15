# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        HE_FPGA.py
# Descriptions:     直方图均衡化（硬件思路验证）
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



def hsv2bgr(bgr: np.ndarray, new_V: np.ndarray):
    tmp = bgr.astype(np.uint32) * new_V.astype(np.uint32)[:, :, None]
    m = bgr.astype(np.uint32).max(axis=-1)[:, :, None]
    m[m == 0] = 1  # 避免除零
    dst = tmp / m
    dst = dst.clip(0, 255).astype(np.uint8)
    return dst


def HE(img: np.ndarray):
    gray = img.max(axis=-1)
    height, width = gray.shape
    pdf = np.zeros(256, dtype=int)
    cdf = np.zeros(256)
    # 统计直方图分布
    for i in range(height):
        for j in range(width):
            index = gray[i][j]
            pdf[index] += 1
    # 计算累积分布直方图
    cdf = pdf.cumsum() // 8192
    cdf = cdf.astype(np.uint8)

    print("cdf done!")

    new_V = np.ndarray(gray.shape)
    # 均衡化
    for i in range(height):
        for j in range(width):
            new_V[i][j] = cdf[gray[i][j]]
    dst = hsv2bgr(img, new_V)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[4:1084, 8:1928]

    start = time()
    dst = HE(src)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    cv2.waitKey()
    cv2.destroyAllWindows()
