# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        AWB_FPGA.py
# Descriptions:     基于灰度世界假设的自动白平衡算法
# -----------------------------------------README-----------------------------------------
# 以G通道为基准，把三个通道的均值调整到同一水平。
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def AWB(img: np.ndarray) -> np.ndarray:
    r = img[:, :, 2].sum() // (2**21)
    g = img[:, :, 1].sum() // (2**21)
    b = img[:, :, 0].sum() // (2**21)
    dst = img.astype(np.int32) * g // np.array([b, g, r])
    dst = dst.clip(0, 255).astype(np.uint8)
    return dst


if __name__ == "__main__":
    path = "./img/day-0.png"
    src = cv2.imread(path)[4:1084, 8:1928]

    start = time()
    dst = AWB(src)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    cv2.waitKey()
    cv2.destroyAllWindows()
