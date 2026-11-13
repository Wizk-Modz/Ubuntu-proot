# Ubuntu Proot: Ubuntu Rootless trên Termux

FFUNUNTU cung cấp giải pháp cài đặt và vận hành môi trường Ubuntu (ARM64) rootless trên Android thông qua Termux và PRoot. Hệ thống thiết lập đầy đủ stubs hệ thống, ánh xạ quyền Android và tối ưu hóa cấu hình cho môi trường di động.

---

## Tính năng chính

- **Kiểm tra tính toàn vẹn gói rootfs**: Tự động tải rootfs qua mạng hoặc nhận diện file nén nội bộ `ubuntu-rootfs-arm64.tar.gz`. Hệ thống xác minh checksum SHA-256 (`2113f8d7eb32748b14581824c1b94cea9ed9a08456312a2e94eddd522d01b927`) trước khi tạo thư mục và tiến hành giải nén.
- **Giả lập thông tin CPU và hệ thống động**:
  - Tự động phát hiện số lõi CPU thực tế đang hoạt động từ `/proc/cpuinfo` để tạo `/proc/stat` và `/proc/uptime` tương ứng.
  - Tái tạo cấu hình CPU mỗi phiên đăng nhập, đồng bộ với trạng thái bật hoặc tắt lõi của nhân Android.
  - Cơ chế kiểm soát quyền sở hữu stubs (`sysdata_own`, `sysdata_clear`) ngăn chặn hành vi can thiệp symlink và hardlink.
- **Quản lý bộ nhớ chia sẻ `/dev/shm`**: Thiết lập thư mục shm độc lập ngang hàng với rootfs (`SysUbuntu.shm`) với quyền `1777` an toàn.
- **Tích hợp quyền người dùng Android**: Tự động phát hiện UID, GID và các nhóm bổ sung của Termux để đăng ký vào `/etc/passwd`, `/etc/group`, `/etc/shadow`, `/etc/gshadow` với tiền tố `aid_*`.
- **Tối ưu hóa hệ thống gói APT/dpkg**: Kích hoạt `force-unsafe-io` giúp tăng tốc độ ghi đĩa trên bộ nhớ flash và cấu hình bỏ qua gói gợi ý/khuyến nghị nhằm tiết kiệm dung lượng lưu trữ.
- **Tự động liên kết đường dẫn Android**: Hỗ trợ gắn kết (bind mount) `/sdcard`, bộ nhớ trong, các đường dẫn runtime của Android (`/apex`, `/system`, `/vendor`) và môi trường Termux vào container.

---

## Yêu cầu hệ thống

- Thiết bị Android chạy kiến trúc CPU **ARM64 (aarch64)**.
- Ứng dụng **Termux** phiên bản mới nhất.
- Dung lượng bộ nhớ trống tối thiểu: **2 GB**.
- Các gói công cụ bắt buộc trên Termux:
  - `proot`
  - `tar`
  - `wget`
  - `coreutils` (cung cấp lệnh `sha256sum`)
  - `termux-tools` (cung cấp lệnh `termux-fix-shebang`)

*Lưu ý: Script `ubuntu.sh` tự động kiểm tra các gói trên và đưa ra thông báo cài đặt tự động nếu phát hiện thiếu gói.*

---

## Cấu trúc thư mục

```
FFUNUNTU/
├── ubuntu.sh                     # Script cài đặt và thiết lập môi trường
├── ubuntu-rootfs-arm64.tar.gz     # Gói nén rootfs Ubuntu ARM64 (nếu có sẵn)
├── start-ubuntu.sh               # Script khởi chạy container (sinh ra sau khi cài đặt)
├── SysUbuntu/                    # Thư mục chứa toàn bộ hệ điều hành Ubuntu (rootfs)
├── SysUbuntu.sysdata/            # Thư mục chứa stubs giả lập /proc và /sys
└── SysUbuntu.shm/                # Thư mục /dev/shm độc lập
```

---

## Hướng dẫn cài đặt

1. Mở Termux và chuyển đến thư mục dự án:
   ```bash
   cd /storage/emulated/0/FFUNUNTU
   ```

2. Cấp quyền thực thi và khởi chạy script thiết lập:
   ```bash
   chmod +x ubuntu.sh
   ./ubuntu.sh
   ```

3. Quy trình thực thi của script:
   - Kiểm tra và nhắc cài đặt các công cụ cần thiết.
   - Kiểm tra tệp `ubuntu-rootfs-arm64.tar.gz` (tải về từ địa chỉ cấu hình nếu chưa có).
   - Xác minh checksum SHA-256 của tệp nén.
   - Tạo thư mục `SysUbuntu` và giải nén rootfs.
   - Thiết lập cấu hình hệ thống, mạng DNS (`8.8.8.8`, `8.8.4.4`) và stubs kernel.
   - Sinh script khởi chạy `start-ubuntu.sh` với quyền thực thi.

---

## Hướng dẫn sử dụng

### 1. Truy cập shell Ubuntu tương tác

Chạy lệnh sau trong Termux để đăng nhập vào môi trường dòng lệnh của Ubuntu:
```bash
./start-ubuntu.sh
```

Container mặc định đăng nhập với người dùng `root` và thư mục làm việc `/root`.

### 2. Chạy lệnh trực tiếp từ Termux

Bạn có thể truyền lệnh bất kỳ vào sau script khởi chạy để thực thi lệnh đó bên trong container rồi thoát ra:
```bash
# Xem thông tin hệ điều hành
./start-ubuntu.sh cat /etc/os-release

# Cập nhật danh sách gói trong Ubuntu
./start-ubuntu.sh apt update

# Cài đặt phần mềm mới
./start-ubuntu.sh apt install -y curl git
```

### 3. Biến môi trường hỗ trợ gỡ lỗi PRoot

Khi cần phân tích hoặc theo dõi hoạt động của PRoot, gán các biến môi trường trước khi chạy:
```bash
PROOT_VERBOSE=1 ./start-ubuntu.sh
```
