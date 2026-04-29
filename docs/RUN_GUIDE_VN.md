# Hướng Dẫn Cài Đặt và Chạy Ứng Dụng RAG Mobile (iOS)

Vì bạn đang sử dụng Windows và không có máy Mac, chúng ta sẽ sử dụng phương pháp **Sideloading** (cài đặt ứng dụng từ bên ngoài App Store) để chạy file `.ipa` đã được build từ GitHub Actions.

## 1. Tải file ứng dụng (.ipa)

1. Truy cập link Releases của bạn: [GitHub Releases](https://github.com/MrCh1s/RAG_Mobile_app/releases)
2. Tìm bản phát hành mới nhất (ví dụ: `v14`).
3. Trong phần **Assets**, hãy tải file có đuôi `.ipa` (ví dụ: `MLCChat.ipa`). Nếu nó nằm trong file `.zip`, hãy giải nén để lấy file `.ipa`.

## 2. Cài đặt bằng Sideloadly (Khuyên dùng cho Windows)

Đây là cách dễ nhất để cài đặt file `.ipa` trên Windows.

### Chuẩn bị:
- Một chiếc iPhone 15 Plus và cáp kết nối.
- Máy tính Windows đã cài đặt **iTunes** (bản tải từ Apple, không phải từ Microsoft Store).
- Tài khoản Apple ID (nên dùng tài khoản phụ nếu bạn lo lắng về bảo mật).

### Các bước thực hiện:
1. **Tải và cài đặt Sideloadly:** [sideloadly.io](https://sideloadly.io/)
2. Kết nối iPhone với máy tính qua cáp USB. Chọn "Tin cậy" (Trust) trên màn hình iPhone nếu được hỏi.
3. Mở Sideloadly:
   - Mục **Device**: Chọn iPhone của bạn.
   - Mục **Apple Account**: Nhập Apple ID của bạn.
   - Kéo và thả file `.ipa` bạn đã tải ở Bước 1 vào ô trống (hoặc nhấn biểu tượng IPA để chọn file).
4. Nhấn **Start**. Sideloadly sẽ yêu cầu mật khẩu Apple ID của bạn (đây là để tạo chứng chỉ cài đặt tạm thời).
5. Đợi quá trình cài đặt hoàn tất (thông báo "Done").

## 3. Cấp quyền trên iPhone

Sau khi cài đặt xong, biểu tượng ứng dụng sẽ xuất hiện trên màn hình chính, nhưng bạn chưa thể mở ngay.

1. Vào **Cài đặt (Settings)** > **Cài đặt chung (General)** > **Quản lý thiết bị & VPN (VPN & Device Management)**.
2. Chọn Apple ID của bạn trong phần "Ứng dụng nhà phát triển" (Developer App).
3. Nhấn **Tin cậy (Trust) [Apple ID của bạn]**.
4. (Nếu dùng iOS 16+) Vào **Cài đặt** > **Quyền riêng tư & Bảo mật** > Bật **Chế độ nhà phát triển (Developer Mode)** và khởi động lại máy nếu yêu cầu.

## 4. Chạy ứng dụng

1. Mở ứng dụng **MLCChat** trên màn hình chính.
2. Ứng dụng sẽ yêu cầu tải dữ liệu model (Qwen2.5-1.5B). Hãy đảm bảo bạn có kết nối Wi-Fi ổn định và đủ dung lượng trống (khoảng 3-4GB).
3. Sau khi tải xong, bạn có thể bắt đầu chat offline!

## 5. Khắc phục lỗi Sideloadly (Nếu gặp lỗi "Initializing Anisette..." hoặc chạy ngầm)

Lỗi này rất phổ biến trên Windows. Bạn hãy thử các cách sau theo thứ tự:

1. **Tắt các tiến trình chạy ngầm:**
   - Nhấn `Ctrl + Shift + Esc` để mở **Task Manager**.
   - Tìm và chọn **Sideloadly** hoặc **SideloadlyDaemon**, nhấn **End Task**.
   - Sau khi tắt hết, hãy thử mở lại ứng dụng.
2. **Kiểm tra khay hệ thống (System Tray):** Đôi khi ứng dụng không mở cửa sổ mà thu nhỏ xuống góc dưới bên phải màn hình (gần đồng hồ). Hãy nhấn vào dấu mũi tên `^` ở đó xem có biểu tượng Sideloadly không.
3. **Quan trọng nhất:** Đảm bảo bạn **KHÔNG** dùng bản iTunes/iCloud từ Microsoft Store.
   - Hãy gỡ cài đặt iTunes/iCloud hiện tại nếu tải từ Store.
   - Tải bản cài đặt trực tiếp (.exe) từ Apple: [iTunes cho Windows](https://www.apple.com/itunes/download/). Sau đó khởi động lại máy.
4. **Thử bản Sideloadly 32-bit:** Nhiều người dùng cho biết bản 64-bit hay bị treo hoặc chạy ngầm, trong khi bản 32-bit chạy ổn định hơn. Hãy tải bản 32-bit tại [sideloadly.io](https://sideloadly.io/).
5. **Chạy với quyền Admin:** Chuột phải vào biểu tượng Sideloadly và chọn **Run as Administrator**.
6. **Cài đặt Anisette nội bộ:**
   - Mở Sideloadly (nếu mở được) > Nhấn vào biểu tượng bánh răng (Settings).
   - Tìm mục **Anisette** và chọn "Local Anisette".
7. **Tạm thời tắt Diệt virus/Firewall:** Đôi khi phần mềm diệt virus chặn cửa sổ ứng dụng hiện lên. Hãy thử tắt tạm thời rồi mở lại Sideloadly.

## 6. Lựa chọn thay thế: Sử dụng AltStore

Nếu Sideloadly vẫn không hoạt động, bạn có thể dùng **AltStore**:
1. Tải **AltServer** trên Windows: [altstore.io](https://altstore.io/)
2. Cài đặt AltStore vào iPhone (cần cắm cáp và mở iTunes).
3. Sau khi có AltStore trên iPhone, bạn tải file `.ipa` từ GitHub về điện thoại, sau đó mở file đó và chọn "Mở bằng AltStore" (Open with AltStore) để cài đặt.

## 7. Khắc phục lỗi "There is no item named 'Payload/...' in the archive"

Nếu Sideloadly báo lỗi này, có nghĩa là file `.ipa` bạn đang dùng bị lỗi cấu trúc (thực chất có thể là một file ZIP khác chứa file IPA bên trong).

**Cách khắc phục:**
1. **Kiểm tra file đã tải:** 
   - Đảm bảo bạn tải file trực tiếp từ mục **Assets** trong phần Release (file có đuôi `.ipa` hoặc nếu là `.zip` thì phải giải nén).
   - **Tuyệt đối không** đổi tên file `.zip` tải từ GitHub Actions thành `.ipa`. Bạn phải giải nén file `.zip` đó ra để lấy file `.ipa` nằm bên trong.
2. **Kiểm tra thủ công:**
   - Trên Windows, bạn hãy thử chuột phải vào file `.ipa` -> chọn **Mở bằng (Open with)** -> chọn **Windows Explorer** hoặc **7-Zip/WinRAR**.
   - Nếu bên trong file bạn thấy có một thư mục tên là **Payload**, thì file đó mới là file chuẩn. 
   - Nếu bên trong bạn lại thấy một file `.ipa` khác hoặc các file như `build.log`, thì bạn cần lấy file `.ipa` bên trong đó ra để dùng cho Sideloadly.
3. **Tải lại:** Nếu file bị lỗi, hãy thử tải lại bản Release mới nhất.
