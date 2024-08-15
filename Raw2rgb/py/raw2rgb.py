# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        raw2rgb.py
# Descriptions:     GBRG格式的RAW图像转为RGB格式
# -----------------------------------------README-----------------------------------------
#
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import cv2
import numpy as np
import sys
sys.path.append("./scripts/")
from img_sim import create_img, gen_txt


def raw2rgb(img: np.ndarray) -> np.ndarray:
    img = img.astype(np.int32)
    height, width = img.shape
    dst = np.ndarray((height, width, 3))
    for i in range(height):
        for j in range(width):
            l = j - 1 if j > 0 else 0
            r = (j + 1) % width
            u = i - 1 if i > 0 else 0
            d = (i + 1) % height
            if(i%2==0 and j%2==0):
                dst[i][j][0] = (img[i][l] + img[i][r]) / 2
                dst[i][j][1] = (img[u][l] + img[u][r] + img[i][j] + img[d][l] + img[d][r]) / 5
                dst[i][j][2] = (img[u][j] + img[d][j]) / 2
            elif(i%2==0 and j%2==1):
                dst[i][j][0] = img[i][j]
                dst[i][j][1] = (img[u][j] + img[i][l] + img[i][r] + img[d][j]) / 4
                dst[i][j][2] = (img[u][l] + img[u][r] + img[d][l] + img[d][r]) / 4
            elif(i%2==1 and j%2==0):
                dst[i][j][0] = (img[u][l] + img[u][r] + img[d][l] + img[d][r]) / 4
                dst[i][j][1] = (img[u][j] + img[i][l] + img[i][r] + img[d][j]) / 4
                dst[i][j][2] = img[i][j]
            elif(i%2==1 and j%2==1):
                dst[i][j][0] = (img[u][j] + img[d][j]) / 2
                dst[i][j][1] = (img[u][l] + img[u][r] + img[i][j] + img[d][l] + img[d][r]) / 5
                dst[i][j][2] = (img[i][l] + img[i][r]) / 2
    dst = dst.astype(np.uint8)
    return dst


if __name__ == "__main__":
    src = create_img("./img/raw_day_0.txt", (1088, 1936), 1)
    dst = raw2rgb(src)[4:1084, 8:1928]

    cv2.imshow("src", cv2.resize(src, (960, 540)))
    cv2.imshow("dst", cv2.resize(dst, (960, 540)))
    cv2.waitKey()
    cv2.destroyAllWindows()
