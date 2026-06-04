import sys
import io

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

import requests

def test_cleanup():
    url = "http://127.0.0.1:8000/notes/cleanup"
    raw_text = "hôm nay tôi đi sthi mua táo, cá, thịt và sữa tươi. quên mất còn phải mua thêm dao cạo râu nữa, chán thế"
    
    print(f"--- ĐANG TEST TÍNH NĂNG CLEAN UP TRÊN WINDOWS ---")
    print(f"Ghi chú gốc:\n{raw_text}\n")
    print("Đang gửi cho AI xử lý (vui lòng chờ 3-5 giây)...")
    
    try:
        response = requests.post(url, json={"content": raw_text})
        if response.status_code == 200:
            data = response.json()
            print("\nKết quả sau khi Clean up:")
            print(data.get("cleaned_content", ""))
        else:
            print(f"Lỗi gọi API: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Không thể kết nối đến máy chủ. Lỗi: {e}")

if __name__ == "__main__":
    test_cleanup()
