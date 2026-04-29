import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from backend.sqlite_notes import NoteManager  # noqa: E402

print("Đang tiến hành dọn dẹp Database...")

# Bật kết nối tới SQLite
db = NoteManager()

# Khởi động lệnh Thanh trừng
db.delete_all_notes()

print(" Hoàn tất! Database của bạn đã trở về trạng thái trống rỗng hoàn toàn.")
