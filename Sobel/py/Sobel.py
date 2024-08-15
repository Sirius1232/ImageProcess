# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        Sobel.py
# Descriptions:     Sobel边缘检测算法
# -----------------------------------------README-----------------------------------------
#
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time


def Sobel(src: np.ndarray):
    gray = cv2.cvtColor(src, cv2.COLOR_BGR2GRAY)
    # 计算水平和垂直方向的梯度
    grad_x = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    grad_y = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    # 计算梯度幅值
    grad_magnitude = np.sqrt(grad_x * grad_x + grad_y * grad_y)
    return grad_magnitude.astype(np.uint8)


if __name__ == "__main__":
    path = "./img/night-0.png"
    src = cv2.imread(path)[4:1084, 8:1928]

    start = time()
    dst = Sobel(src)
    print(f"Running time = {time()-start}s")

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    cv2.waitKey()
    cv2.destroyAllWindows()
