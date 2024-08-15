# ****************************************************************************************#
# Encoding:         UTF-8
# ----------------------------------------------------------------------------------------
# File Name:        img_sim.py
# Descriptions:     用于编解码RTL仿真用的图像的txt数据
# -----------------------------------------README-----------------------------------------
# txt里的每一行代表一个像素点数据。
#
# ----------------------------------------------------------------------------------------
# ****************************************************************************************#


import numpy as np
import cv2


def gen_txt(img_path: str, out_path: str, channel: int = 3):
    """将图像文件转换为txt数据，用于仿真"""
    img = cv2.imread(img_path)
    img = cv2.resize(img, (320, 240))
    if(channel==1):
        img = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    height, width = img.shape[0], img.shape[1]
    with open(out_path, "w") as f:
        for i in range(height):
            for j in range(width):
                if(channel==1):
                    f.write(hex(img[i][j])[2:] + "\n")
                elif(channel==3):
                    txt = "{:0>2}{:0>2}{:0>2}\n".format(hex(img[i][j][2])[2:], hex(img[i][j][1])[2:], hex(img[i][j][0])[2:])
                    f.write(txt)


def create_img(txt_path: str, shape=(1080, 1920), channel: int=3) -> np.ndarray:
    """将仿真输出的txt数据转换为图像显示"""
    if(channel==1):
        img = np.ndarray((shape[0], shape[1]), dtype=np.uint8)
    elif(channel==3):
        img = np.ndarray((shape[0], shape[1], 3), dtype=np.uint8)
    height, width = shape[0], shape[1]
    with open(txt_path, "r") as f:
        txt = f.read().split("\n")
    for i in range(height):
        for j in range(width):
            if(channel==1):
                img[i][j] = bytes.fromhex(txt[i * width + j])[0]
            elif(channel==3):
                img[i][j][2], img[i][j][1], img[i][j][0] = bytes.fromhex(txt[i * width + j])
    img = img.astype(np.uint8)
    return img


if __name__ == "__main__":
    # gen_txt("./img/day-0.png", "./img/raw_day_0.txt", 3)
    dst = create_img("./img/raw_day_0.txt", (1088, 1936), 1)
    cv2.imshow("", cv2.resize(dst, (960, 540)))
    while True:
        k = cv2.waitKey(1) & 0xFF
        if k == ord("q"):  # 按下q键，程序退出
            break
    cv2.destroyAllWindows()  # 释放并销毁窗口
