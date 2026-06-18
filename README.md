# Hướng dẫn Cài đặt Ứng dụng AI Notebook (.ipa) lên iPhone/iPad

Vì ứng dụng này tích hợp bộ não AI Qwen2.5 (chạy cục bộ 100% offline) và sử dụng bộ nhớ RAM rất lớn, ứng dụng chưa được đưa lên App Store. Để cài đặt file `.ipa` anh/chị tải về từ GitHub Actions lên iPhone, anh/chị cần sử dụng phương pháp **Sideloading**.

Dưới đây là hướng dẫn chi tiết cách cài đặt qua **Sideloadly** (công cụ dễ nhất dành cho người dùng Windows).

---

## 🛠 Yêu cầu chuẩn bị
1. File **`MLCChat-Qwen2.5-1.5B.ipa`** (Tải về từ mục Artifacts trong tab Actions trên GitHub của anh/chị).
2. Máy tính Windows (hoặc Mac).
3. Cáp kết nối iPhone với máy tính.
4. Tài khoản Apple ID (Khuyến cáo nên tạo một Apple ID phụ/ảo để đảm bảo an toàn tuyệt đối).
5. **Thiết bị:** iPhone/iPad có RAM từ 4GB trở lên (từ iPhone 11 trở lên) chạy iOS 15.0+.

---

## 🚀 Các bước cài đặt bằng Sideloadly

### Bước 1: Cài đặt Sideloadly & iTunes
- Tải và cài đặt **iTunes** (Bản tải trực tiếp từ web Apple, *không tải từ Microsoft Store*): [Link tải iTunes](https://www.apple.com/itunes/)
- Tải và cài đặt **iCloud cho Windows**: [Link tải iCloud](https://support.apple.com/en-us/HT204283)
- Tải và cài đặt **Sideloadly**: [Link tải Sideloadly](https://sideloadly.io/)

### Bước 2: Kết nối iPhone với máy tính
1. Cắm cáp kết nối iPhone với máy tính.
2. Mở khóa màn hình iPhone. Nếu hiện thông báo **"Tin cậy máy tính này" (Trust this computer)**, hãy bấm **Tin cậy** và nhập mật khẩu màn hình.
3. Mở phần mềm iTunes lên để đảm bảo iTunes đã nhận diện được điện thoại.

### Bước 3: Cài đặt file .ipa
1. Mở phần mềm **Sideloadly** lên.
2. Ở mục **iDevice**, chọn thiết bị iPhone của anh/chị (nó sẽ hiện ra mã thiết bị nếu kết nối thành công).
3. Ở ô **Apple ID**, nhập tài khoản Apple ID của anh/chị (nên dùng Apple ID phụ).
4. Bấm vào biểu tượng **IPA** (hình cái hộp ở cột bên trái) và chọn đường dẫn đến file `MLCChat-Qwen2.5-1.5B.ipa` anh/chị vừa tải về.
5. Bấm nút **Start** để bắt đầu.
6. Sideloadly sẽ yêu cầu anh/chị nhập mật khẩu Apple ID. Hãy nhập mật khẩu. *(Lưu ý: Sideloadly chỉ gửi tài khoản này lên server của Apple để xin chữ ký số, hoàn toàn không lưu trữ).*
7. Chờ đợi từ 3-5 phút. Khi thanh trạng thái hiện chữ **Done**, ứng dụng đã được cài lên điện thoại!

---

## 🔓 Bước 4: Cấp quyền chạy ứng dụng trên iPhone (Rất quan trọng)

Anh/chị chưa thể mở app ngay lập tức. Apple yêu cầu anh/chị phải "Tin cậy" nhà phát triển.

### 1. Bật chế độ Nhà phát triển (Developer Mode) - Chỉ dành cho iOS 16 trở lên
- Mở **Cài đặt (Settings)** > **Quyền riêng tư & Bảo mật (Privacy & Security)**.
- Cuộn xuống dưới cùng, tìm mục **Chế độ nhà phát triển (Developer Mode)** và Bật nó lên.
- Điện thoại sẽ yêu cầu **Khởi động lại (Restart)**.
- Sau khi khởi động lại, mở khóa màn hình, sẽ có một bảng thông báo hỏi xác nhận, bấm **Bật (Turn On)** và nhập mật khẩu màn hình.

### 2. Tin cậy Chứng chỉ Ứng dụng
- Mở **Cài đặt (Settings)** > **Cài đặt chung (General)**.
- Chọn **Quản lý VPN & Thiết bị (VPN & Device Management)**.
- Dưới mục *Ứng dụng của nhà phát triển (Developer App)*, anh/chị sẽ thấy email Apple ID của mình. Bấm vào đó.
- Bấm **Tin cậy "Email_của_anh/chị" (Trust "...")** và xác nhận.

🎉 **HOÀN TẤT!** Bây giờ anh/chị có thể quay ra màn hình chính, mở ứng dụng và trải nghiệm AI Sổ tay 100% Offline (bao gồm cả Semantic Search)!

---

## 📱 Hướng dẫn sử dụng ứng dụng

**Bước 1:** Bấm vào model `qwen2.5-1.5b......`
**Bước 2:** Đợi nạp model, sau đó thoát ra khỏi màn hình chat
**Bước 3:** Vào biểu tượng sổ tay để điền ghi chú, thực hiện clean up, phân loại ghi chú
**Bước 4:** Tiến hành hỏi đáp

---

## ⚠️ Lưu ý quan trọng
- **Gia hạn chứng chỉ:** Vì dùng tài khoản Apple ID miễn phí, ứng dụng sẽ bị **hết hạn sau 7 ngày**. Sau 7 ngày, app sẽ bị văng khi mở. Anh/chị KHÔNG cần xóa app, chỉ cần cắm cáp vào máy tính, mở Sideloadly và làm lại Bước 3 (dữ liệu sổ tay vẫn sẽ được giữ nguyên).
- **Tránh tràn RAM:** App tích hợp lõi AI nên ngốn rất nhiều RAM. Hãy **đóng các ứng dụng chạy ngầm** (như game nặng, camera) trước khi hỏi đáp với AI để tránh bị văng app do iOS tự động kill process.
