# Hướng dẫn chạy từng bước trên Windows

## 1. Chuẩn bị

Cài các công cụ sau từ trang chính thức:

- VS Code: https://code.visualstudio.com/ — cài extension **Flutter** (tự kèm Dart).
- Flutter SDK: https://docs.flutter.dev/install — bản project nhắm Flutter **3.35.7 / Dart 3.9.2**, có thể dùng Flutter stable mới tương thích. Giải nén SDK vào đường dẫn không dấu/không khoảng trắng, ví dụ `C:\src\flutter`; thêm `C:\src\flutter\bin` vào PATH.
- Git: https://git-scm.com/download/win.
- Chrome để thử giao diện web nhanh.
- Docker Desktop: https://www.docker.com/products/docker-desktop/ nếu dùng cách A. Khởi động Docker Desktop trước khi chạy lệnh.
- Android Studio và Android SDK nếu chạy giả lập Android: https://developer.android.com/studio.
- Node.js 22 hoặc 24 LTS nếu dùng cách B: https://nodejs.org/.

Kiểm tra bằng Terminal mới:

```powershell
flutter --version
flutter doctor
docker --version
docker compose version
```

Nếu thiếu Android SDK Command-line Tools: mở Android Studio → SDK Manager → SDK Tools, cài Android SDK Command-line Tools. Sau đó chạy `flutter doctor --android-licenses` và đọc/chấp nhận giấy phép để sử dụng SDK. Chỉ cần toolchain cho nền tảng sẽ chạy; chưa cần xử lý mục Visual Studio C++ nếu không chạy Windows desktop.

## 2. Mở project

Giải nén file ZIP, ví dụ vào `C:\Projects\expense_manager`. Mở VS Code → File → Open Folder → chọn thư mục **expense_manager** có `compose.yaml` và `README.md`. Chọn Terminal → New Terminal.

## 3A. Chạy backend và database bằng Docker (dễ nhất)

Tại thư mục gốc:

```powershell
docker compose up --build -d
docker compose ps
docker compose logs api
```

Lần đầu cần Internet để tải image và thư viện. Backend tự chạy migration, tạo bảng rồi mở cổng 3000.

Mở `http://localhost:3000/health` trên trình duyệt, kết quả mong đợi:

```json
{"status":"ok"}
```

Tạo dữ liệu mẫu (không bắt buộc):

```powershell
docker compose exec api npm run seed
```

Đăng nhập `demo@example.com`, mật khẩu `Demo@12345`. Hoặc bấm Đăng ký để tạo tài khoản riêng.

Dừng ứng dụng: `docker compose down`. Dữ liệu vẫn còn trong Docker volume. **Không thêm `-v` nếu muốn giữ dữ liệu**. Sau này mở lại bằng `docker compose up -d`.

## 3B. Cách khác: chạy trực tiếp, không dùng Docker

Không cần làm mục này nếu đã dùng 3A. Cài PostgreSQL 17 (pgAdmin thường đi kèm). Mở pgAdmin và kết nối máy chủ PostgreSQL. Trong database `postgres`, mở Query Tool chạy:

```sql
CREATE USER expense WITH PASSWORD 'expense_local_2026';
```

Chạy câu sau **riêng**, không nằm trong `BEGIN/COMMIT`:

```sql
CREATE DATABASE expense_db OWNER expense;
```

Mở Terminal VS Code:

```powershell
cd backend
Copy-Item .env.example .env
npm ci
npm run migrate
npm run seed
npm run dev
```

Giữ Terminal này đang chạy. File `backend/.env` phải khớp tài khoản, mật khẩu, port PostgreSQL trên máy. Nếu mật khẩu có ký tự đặc biệt trong URL, cần URL-encode ký tự đó. Ví dụ này là thông tin local để học, không dùng trên server công khai.

## 4. Chạy Flutter trên Chrome trước

Mở Terminal thứ hai tại thư mục gốc project:

```powershell
cd mobile
flutter pub get
flutter run -d chrome --web-port 5173 --dart-define=API_BASE_URL=http://localhost:3000/api
```

Chrome mở ứng dụng. Thử đăng ký hoặc tài khoản mẫu. Dùng đúng port 5173 để khớp CORS đã cấu hình.

## 5. Chạy Android Emulator

1. Android Studio → Device Manager → Create Virtual Device, chọn máy và system image rồi khởi động.
2. Terminal tại `mobile` chạy `flutter devices`.
3. Sao chép ID thiết bị, ví dụ `emulator-5554`:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:3000/api
```

`10.0.2.2` là địa chỉ máy tính Windows từ Android Emulator tiêu chuẩn; `localhost` bên trong giả lập là chính giả lập.

### Dùng LDPlayer

Bật ADB trong cài đặt LDPlayer, tìm thiết bị bằng `adb devices` (hoặc `flutter devices`). Nếu thiết bị xuất hiện, cách dễ kiểm tra kết nối API là chuyển tiếp cổng ADB:

```powershell
adb -s <DEVICE_ID> reverse tcp:3000 tcp:3000
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

Thay `<DEVICE_ID>` bằng ID thực tế. ADB nằm trong Android SDK `platform-tools`; thêm thư mục đó vào PATH nếu báo không tìm thấy lệnh. Không giả định LDPlayer luôn dùng cổng ADB cố định. Nếu LDPlayer không hỗ trợ `adb reverse`, dùng IP LAN của máy tính như mục dưới.

### Điện thoại Android thật

Bật Developer options và USB debugging, kết nối USB và chấp nhận yêu cầu gỡ lỗi. Dùng `adb reverse` như trên. Hoặc cho máy tính và điện thoại cùng Wi-Fi, chạy `ipconfig` trên Windows để xem IPv4, ví dụ `192.168.1.10`, rồi:

```powershell
flutter run -d <DEVICE_ID> --dart-define=API_BASE_URL=http://192.168.1.10:3000/api
```

Cho phép Node/Docker truy cập mạng **Private** trong Windows Firewall khi được hỏi. IP ví dụ phải thay bằng IP máy bạn. Backend nghe trên `0.0.0.0:3000`.

## 6. Sử dụng

1. Đăng ký họ tên, email, mật khẩu ít nhất 8 ký tự.
2. Ứng dụng tạo sẵn 8 danh mục; mở **Danh mục** để thêm/sửa.
3. Chọn **Thêm giao dịch** → Thu/Chi → số tiền nguyên (ví dụ `50000`) → danh mục → ngày → Lưu.
4. Mở **Giao dịch** để lọc, tìm, sửa hoặc xóa qua nút ba chấm. Chuyển tháng bằng mũi tên hoặc bấm tên tháng và chọn một ngày trong tháng cần xem.
5. Mở **Ngân sách**, đặt hạn mức cho danh mục chi. Đỏ nghĩa là chi thực tế đã vượt hạn mức; ứng dụng không chặn ghi giao dịch.
6. **Tổng quan** hiển thị thống kê của tất cả giao dịch tháng, độc lập với bộ lọc/từ khóa màn hình Giao dịch.
7. Menu góc phải → Đăng xuất. Phiên đó được thu hồi trên backend.

## 7. Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `flutter` / `node` / `npm` không nhận lệnh | Kiểm tra PATH, đóng và mở lại VS Code/Terminal. |
| PowerShell chặn `npm.ps1` | Dùng `npm.cmd ci`, `npm.cmd run dev`, hoặc Terminal Command Prompt. |
| Docker báo không kết nối daemon | Mở Docker Desktop, đợi Engine chạy. |
| Port 5432 đã được dùng | Nếu đã cài PostgreSQL local, đổi phần port DB compose thành `127.0.0.1:5433:5432`; API trong Docker vẫn dùng `db:5432`. |
| Port 3000 đã được dùng | Dừng API cũ; tránh chạy đồng thời cả cách 3A và 3B trên cùng cổng. |
| Flutter không kết nối API | Kiểm tra `/health`, địa chỉ host theo thiết bị, Wi-Fi, firewall. Hot restart sau khi đổi `--dart-define`. |
| Chrome bị CORS | Dùng port 5173; kiểm tra `CORS_ORIGINS` rồi khởi động lại API. Nếu dùng tên host khác phải bổ sung đúng origin. |
| “Danh mục đã được dùng…” khi xóa | Xóa hoặc chuyển các giao dịch và xóa ngân sách liên quan trước; đây là ràng buộc giữ dữ liệu. |
| Không thấy giao dịch mẫu | Chọn tháng đã chạy seed lần đầu. Seed không tự tạo thêm dữ liệu vào tháng mới nếu tài khoản mẫu đã tồn tại. |
| `pub get` lỗi mạng | Kiểm tra Internet/proxy, thử lại. Không cần sửa source code. |
| Phiên hết hạn | Access token 15 phút được tự làm mới; đăng nhập lại nếu refresh token hết hạn (14 ngày) hoặc phiên bị thu hồi. |

## 8. Build và test

```powershell
# Trong mobile
flutter analyze
flutter test
flutter build web --dart-define=API_BASE_URL=https://api.ten-mien-cua-ban.vn/api

# Trong backend
npm test
```

Project không kèm file APK ký phát hành. Khi chuẩn bị bản release Android, cấu hình HTTPS cho API và khóa ký riêng; không sử dụng khóa ký demo để phát hành. Không đưa khóa ký hoặc mật khẩu vào Git.

## Cấu hình JWT sau khi cập nhật backend

Bổ sung `JWT_ACCESS_SECRET` vào `backend/.env`, ít nhất 32 ký tự. Refresh token được sinh ngẫu nhiên và lưu bản băm trong database nên không cần `JWT_REFRESH_SECRET`. Tạo secret bằng `node -e "console.log(require('node:crypto').randomBytes(48).toString('hex'))"`. Docker Compose đọc biến này từ môi trường hoặc `.env` ở thư mục gốc; giá trị mặc định trong Compose chỉ dành cho demo local.

Chạy `cd backend`, `npm run migrate`, rồi `npm start`. Migration `002_refresh_jwt_sessions.sql` thu hồi phiên opaque cũ; người dùng cần đăng nhập lại. Client Flutter dùng refresh cookie và `/api/users/me`; client cũ cần đăng nhập lại. Khóa lưu trữ cũ `session_token` không được dùng lại. Backend kiểm tra cấu hình JWT khi khởi động và báo lỗi nếu thiếu secret hoặc secret quá ngắn.

Cookie production dùng Secure + SameSite=None nên cần HTTPS. Local dùng cùng hostname cho Flutter Web và API (ví dụ localhost). Browser bật gửi credentials; các POST auth cần header `X-Requested-With: expense-manager`. CORS_ORIGINS phải chứa đúng origin Flutter. API refresh/logout không còn nhận refresh token trong JSON.
