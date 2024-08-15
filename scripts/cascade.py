# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        cascade.py
# Descriptions:     算法级联
# -----------------------------------------README-----------------------------------------
#
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
from time import time
import sys
sys.path.append("./Raw2rgb/py/")
sys.path.append("./CLAHE/py/")
sys.path.append("./HE/py/")
sys.path.append("./AWB/py/")
sys.path.append("./Scaling/py/")
sys.path.append("./Retinex/py/")
sys.path.append("./Sobel/py/")

from raw2rgb import raw2rgb
from CLAHE_FPGA import CLAHE
from HE_FPGA import HE
from AWB_FPGA import AWB
from BiLinear_FPGA import bi_linear
from Retinex_FPGA import Retinex
from Sobel import Sobel

from img_sim import create_img, gen_txt


if __name__ == "__main__":
    path = "./img/raw_day_0.txt"
    # path = "./raw_night_0.txt"
    src = raw2rgb(create_img(path, (1088, 1936), 1))[3:1083, 7:1927]
    # src = raw2rgb(create_img(path, (1088, 1936), 1))[184:903, 328:1605]  # 1.5
    # src = raw2rgb(create_img(path, (1088, 1936), 1))[255:831, 455:1479]  # 1.875
    # src = raw2rgb(create_img(path, (1088, 1936), 1))[272:814, 486:1448]  # 2

    start = time()
    cv2.imshow("src", cv2.resize(src, (960, 540)))
    dst = src.copy()
    # dst = bi_linear(src, 1.5)
    # cv2.imshow("scaling", cv2.resize(dst, (960, 540)))
    dst = Retinex(dst)
    cv2.imshow("Retinex", cv2.resize(dst, (960, 540)))
    dst = HE(dst)
    cv2.imshow("HE", cv2.resize(dst, (960, 540)))
    dst = AWB(dst)
    cv2.imshow("AWB", cv2.resize(dst, (960, 540)))
    print(f"Running time = {time()-start}s")

    while True:
        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):  # 按下q键，程序退出
            break
    cv2.destroyAllWindows()  # 释放并销毁窗口