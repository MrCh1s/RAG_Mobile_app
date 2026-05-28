# Hướng Dẫn Kiểm Thử (Test) AI Sổ Tay Trên App iOS (Local Offline Hoàn Toàn)

Ứng dụng iOS của bạn được tích hợp công cụ **MLC-LLM Swift** chạy mô hình ngôn ngữ lớn (LLM) trực tiếp trên chip Apple Silicon (iPhone/iPad hoặc Simulator Mac) mà **không cần kết nối Internet**.

Dưới đây là tài liệu hướng dẫn kiểm thử các tính năng AI bao gồm **Clean Up (chuẩn hóa ghi chú)** và **Auto-Tagging & Classification (tự động phân loại/gắn nhãn)** ngay trên thiết bị.

---

## 1. Chuẩn Bị & Chạy Ứng Dụng Trên iOS

Để chạy mô hình AI offline trên thiết bị:
1. Mở Xcode dự án: [MLCChat.xcodeproj](file:///e:/Qwen-MLC-workspace/apps/ios_app/MLCChat/MLCChat.xcodeproj).
2. Kết nối thiết bị iPhone thật hoặc chọn một thiết bị **iOS Simulator** trong Xcode.
3. Nhấn nút **Run** (Cmd + R) để cài đặt và khởi động ứng dụng.
4. Trên ứng dụng di động:
   * Chọn model AI (ví dụ: `Qwen2.5-1.5B-Instruct-q4f16_1` hoặc model tương đương bạn đã đóng gói).
   * Đợi ứng dụng tải model lên RAM (quá trình này mất khoảng vài giây). Khi trạng thái đổi thành **`[System] Ready to chat`** (ở phía dưới màn hình), hệ thống AI cục bộ đã sẵn sàng hoạt động.

---

## 2. Kịch Bản Kiểm Thử Tính Năng "Clean Up" (AI)

Tính năng này giúp chuẩn hóa ghi chú viết nhanh, lộn xộn, không dấu thành ghi chú có định dạng cấu trúc rõ ràng và dễ đọc.

### Các bước test:
1. Nhấn vào mục **Sổ tay AI** (được định nghĩa trong [NoteEditView.swift](file:///e:/Qwen-MLC-workspace/apps/ios_app/MLCChat/MLCChat/Views/NoteEditView.swift)).
2. Nhập một đoạn ghi chú nhanh không chuẩn hóa vào khung văn bản:
   > *"nho di cho mua sua cho be luc 5h chieu tien the mua them ti hanh tay thit bo lam com chieu luon nhe"*
3. Nhấn vào nút **`Clean Up (AI)`** (nút màu tím có hình lấp lánh).
4. **Kết quả mong đợi (Expected Outcome):**
   * Màn hình hiển thị lớp phủ xoay tròn: *"AI đang định dạng và chuẩn hóa..."*
   * Sau khi hoàn tất (chạy trực tiếp bằng MLCEngine offline), nội dung ghi chú sẽ được thay thế bằng định dạng Markdown sạch sẽ như:
     ```markdown
     **Nhiệm vụ mua sắm chiều nay:**
     * Mua sữa cho bé (lúc 17:00).
     * Mua hành tây và thịt bò để chuẩn bị bữa tối.
     ```

---

## 3. Kịch Bản Kiểm Thử Tính Năng "Phân Loại & Đánh Tag Tự Động"

Tính năng này giúp tự động hóa việc đưa ghi chú vào đúng Thư mục (Folder) và gắn các thẻ (Tags) liên quan để người dùng tìm kiếm nhanh chóng.

### Các bước test:
1. Nhập nội dung ghi chú (ví dụ ghi chú đã được Clean Up hoặc ghi chú thô mới như: *"Thanh toán tiền điện tháng này hết 1tr2 qua app ngân hàng"*).
2. Nhấn nút **`Lưu Ghi Chú`** (nút màu xanh dương).
3. **Kết quả mong đợi (Expected Outcome):**
   * Lớp phủ hiển thị: *"AI đang phân loại và gắn nhãn..."*
   * Mô hình Qwen chạy offline trên thiết bị sẽ phân tích văn bản và trả về JSON chứa thông tin phân loại:
     ```json
     {
       "folder": "Tài chính",
       "tags": ["tiền điện", "thanh toán"]
     }
     ```
   * Ứng dụng tự động lưu ghi chú này vào SQLite cục bộ (`notes.db`) bằng hàm `LocalDatabase.shared.insertNote`.
   * Ghi chú biến mất khỏi ô nhập và xuất hiện ở danh sách ghi chú bên dưới, được phân loại chính xác dưới Thư mục **`Tài chính`** với các nhãn tag như `#tiền điện`, `#thanh toán`.
   * Trên thanh trượt ngang (Folder Filter Bar), bạn sẽ thấy xuất hiện thêm thẻ **`Tài chính`**. Nhấn chọn thẻ này sẽ lọc chính xác ghi chú vừa tạo.

---

## 4. Kiểm Tra Luồng Code Thực Thi (Swift Offline Logic)

Mọi xử lý offline trên thiết bị đều nằm trong các file mã nguồn sau:
* **UI & Hành động kích hoạt**: Xem trong [NoteEditView.swift](file:///e:/Qwen-MLC-workspace/apps/ios_app/MLCChat/MLCChat/Views/NoteEditView.swift) tại hàm:
  - `cleanupNoteText()` (Dòng 218)
  - `saveNoteWithAI()` (Dòng 232)
* **Xử lý gọi Mô hình LLM cục bộ**: Xem trong [ChatState.swift](file:///e:/Qwen-MLC-workspace/apps/ios_app/MLCChat/MLCChat/States/ChatState.swift) tại hàm:
  - `cleanUpNoteText(rawText:)` (Dòng 450)
  - `classifyAndTagNoteText(rawText:)` (Dòng 473)
* **Cơ sở dữ liệu SQLite cục bộ**: Xem trong [LocalDatabase.swift](file:///e:/Qwen-MLC-workspace/apps/ios_app/MLCChat/MLCChat/LocalDatabase.swift) tại hàm:
  - `insertNote(content:folderName:tags:)` (Dòng 89)
