# Kiểm thử và nghiệm thu

## 1. Chạy kiểm thử tự động

Backend:
```powershell
cd backend
npm ci
npm test
```

Mặc định dùng **PGlite**, lõi PostgreSQL biên dịch sang WebAssembly, tạo database tạm trong bộ nhớ. Đây không phải mock trả kết quả SQL cố định. Kiểm thử đi qua HTTP của Express và thực thi SQL/ràng buộc thật trong PGlite. Không cần Docker và không đụng database làm việc.

Để chạy cùng bộ test trên PostgreSQL server thật, tạo **database kiểm thử mới và rỗng**, sau đó:

```powershell
$env:TEST_DATABASE_URL="postgresql://expense:expense_local_2026@localhost:5432/expense_test"
npm test
Remove-Item Env:TEST_DATABASE_URL
```

Test từ chối chạy nếu public schema đã có bảng. Test không tự xóa database; sau khi chạy, database test vẫn còn dữ liệu và lần sau cần database rỗng mới. Không dùng `expense_db` đang chứa dữ liệu làm `TEST_DATABASE_URL`.

Flutter:
```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
```

## 2. Các tình huống API đã đưa vào test

| STT | Tình huống | Kỳ vọng |
|---|---|---|
| 1 | Gọi API riêng tư khi chưa đăng nhập | 401 |
| 2 | Đăng ký tài khoản | Tạo phiên, 8 danh mục mặc định, mật khẩu được băm |
| 3 | Trùng email, sai mật khẩu; đăng nhập đúng | Lần lượt 409, 401, 200 |
| 4 | Tiền âm/0/lẻ/quá giới hạn, ngày sai, danh mục sai loại hoặc tài khoản | 400 |
| 5 | Giao dịch cuối tháng/đầu tháng sau | Tổng tháng không lẫn dữ liệu tháng sau |
| 6 | Phân trang, bộ lọc, chuỗi tìm kiếm giống SQL | Kết quả đúng; chuỗi không trở thành câu SQL |
| 7 | Tài khoản B xem/sửa/xóa giao dịch của A | Không thấy dữ liệu, không thể sửa/xóa |
| 8 | Tạo/cập nhật ngân sách; danh mục đã dùng | Một bản duy nhất; tiền đã chi đúng; chặn xóa danh mục |
| 9 | Sửa/xóa giao dịch, tháng rỗng | Tổng thu–chi và ngân sách cập nhật; tháng rỗng bằng 0 |
| 10 | CRUD danh mục, tên trùng khác hoa/thường | Lưu/sửa/xóa đúng; chặn trùng |
| 11 | Phiên hết hạn hoặc đã đăng xuất | Không dùng lại được |

## 3. Flutter test

- Kiểm tra nhập tiền nguyên VND và định dạng ngày/tháng.
- Kiểm tra bearer token, JSON tiếng Việt, xử lý HTTP 401.
- Form đăng nhập chặn email/mật khẩu không hợp lệ trước khi gửi API.
- Màn hình tổng quan đọc dữ liệu API và chuyển sang danh sách rỗng.

## 4. Checklist chạy thử bằng giao diện của nhóm

1. Đăng ký một tài khoản mới, xác nhận danh sách giao dịch rỗng.
2. Thêm khoản thu 5.000.000 đồng và khoản chi 50.000 đồng cùng tháng. Tổng quan phải hiển thị chênh lệch 4.950.000 đồng.
3. Sửa khoản chi thành 80.000 đồng. Tổng chi và biểu đồ phải cập nhật.
4. Đặt ngân sách 60.000 đồng cho đúng danh mục. Ứng dụng phải báo vượt 20.000 đồng.
5. Xóa khoản chi sau xác nhận. Tổng chi về 0; ngân sách còn 60.000 đồng.
6. Thêm một giao dịch vào tháng trước; chuyển qua lại giữa hai tháng để kiểm tra bộ lọc.
7. Tạo danh mục tiếng Việt, tìm giao dịch bằng ghi chú tiếng Việt.
8. Đăng xuất, đăng ký tài khoản thứ hai, xác nhận không có dữ liệu của tài khoản thứ nhất.
9. Dừng backend; thử tải lại để kiểm tra thông báo lỗi. Mở backend lại và bấm Thử lại.
10. Đóng/mở ứng dụng: phiên còn hạn được khôi phục; sau đăng xuất không khôi phục.
11. Thử trên điện thoại/giả lập màn hình nhỏ, mở bàn phím và cuộn form tới nút Lưu.

## 5. Giới hạn của bản 1.0

- Chỉ VND, một sổ giao dịch cá nhân; chưa quản lý nhiều ví hoặc số dư đầu kỳ.
- Cần mạng để đọc/ghi; chưa có hàng đợi đồng bộ offline.
- Không tự đọc dữ liệu ngân hàng, không OCR hóa đơn.
- Chưa xác minh email, quên mật khẩu hay quản trị tài khoản.
- Chưa có xuất báo cáo tệp hoặc thông báo đẩy; cảnh báo ngân sách hiển thị trong app.
- Session hết hạn theo thời gian cố định; chưa có refresh token hoặc màn hình quản lý tất cả thiết bị.
- Chưa có APK ký phát hành; Android cần chạy thử với SDK/thiết bị của nhóm.
- Kiểm thử PGlite không thay thế hoàn toàn kiểm thử triển khai PostgreSQL qua TCP, Docker, firewall và Android thực tế.

Kết quả công cụ thực tế cho gói bàn giao được ghi ở `docs/KET_QUA_KIEM_THU.txt`.

## Kiểm thử access JWT và refresh token trong DB

- `backend/test/api.test.js`: đăng ký/đăng nhập, hồ sơ từ DB, cookie và hash trong DB, thời hạn 14 ngày cố định, refresh đồng thời, CORS/CSRF, logout, hết hạn session, cách ly tài khoản và nghiệp vụ thu chi.
- `backend/test/tokens.test.js`: thời hạn 15 phút/14 ngày; từ chối token sai loại, hết hạn, sai chữ ký/issuer/audience/algorithm, thiếu claims; xác minh cấu hình secret.
- `mobile/test/app_test.dart`: bổ sung kiểm thử gộp refresh đồng thời, retry một lần, giữ phiên khi lỗi mạng/429/503, lưu/khôi phục/xóa cookie ở lớp HTTP native, phạm vi origin/path của cookie.

Kiểm tra cập nhật ngày 14/10/2026: backend chạy với PostgreSQL WASM tạm thời (UTC). Flutter/Dart chưa có trên PATH của môi trường thực hiện thay đổi, nên các kiểm thử mobile bổ sung chưa được chạy; cần chạy `flutter analyze` và `flutter test` trên máy có SDK. Kết quả cũ trong `KET_QUA_KIEM_THU.txt` không chứng nhận các thay đổi JWT này.
