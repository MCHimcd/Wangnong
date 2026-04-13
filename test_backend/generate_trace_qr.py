"""
溯源码二维码生成器
生成一个测试用二维码图片，扫描后可在 Wangnong 前端进入溯源详情页。

使用方法:
    pip install qrcode[pil]
    python generate_trace_qr.py

二维码内容为批次号 "WN-2026-A03-0412"，对应 test_backend/server.py 中的模拟数据。
生成文件: trace_qr.png (当前目录)
"""

import qrcode

TRACE_CODE = "WN-2026-A03-0412"

def main():
    qr = qrcode.QRCode(
        version=2,
        error_correction=qrcode.constants.ERROR_CORRECT_M,
        box_size=12,
        border=4,
    )
    qr.add_data(TRACE_CODE)
    qr.make(fit=True)
    img = qr.make_image(fill_color="#1B5E20", back_color="white")
    out_path = "trace_qr.png"
    img.save(out_path)
    print(f"二维码已生成: {out_path}")
    print(f"内容: {TRACE_CODE}")
    print("用手机扫描此二维码，即可在鸿蒙慧田 App 中查看完整溯源信息。")

if __name__ == "__main__":
    main()
