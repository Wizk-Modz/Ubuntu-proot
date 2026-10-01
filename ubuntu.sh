#!/data/data/com.termux/files/usr/bin/bash
#
# ubuntu.sh — dựng container Ubuntu rootless trên Termux (thủ công).
#
# Các bước setup hệ thống mô phỏng proot-distro:
#   - fake /proc, /sys stubs trong thư mục sysdata/
#   - /dev/shm là thư mục sibling của rootfs (mode 1777), KHÔNG phải <rootfs>/tmp
#   - /etc/resolv.conf và /etc/hosts được THAY THẾ (không append trùng)
#   - chmod 0644 cho passwd/shadow/group/gshadow
#   - đăng ký Android UID/GID (aid_*) idempotent
#   - env identity: PD_CONTAINER, container=proot-distro
#   - passthrough PROOT_VERBOSE / PROOT_DBG_STOPS từ môi trường người dùng
#   - profile.d snippet sinh động, re-export biến khi `su -`
#
# Chạy: ./ubuntu.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FOLDER="SysUbuntu"
ROOTFS="$SCRIPT_DIR/$FOLDER"
SYSDATA_DIR="$SCRIPT_DIR/$FOLDER.sysdata"
SHM_DIR="$SCRIPT_DIR/$FOLDER.shm"
TARBALL="$SCRIPT_DIR/ubuntu-rootfs.tar.gz"
TERMUX_USR="${PREFIX:-$HOME/../usr}"

# In giá trị biến có tên $1 nếu đã set; trả về 1 nếu chưa set. An toàn với
# `set -u` — khác ${!name} trực tiếp (báo lỗi "invalid indirect expansion").
env_value() {
	declare -p "$1" >/dev/null 2>&1 || return 1
	printf '%s' "${!1}"
}

# === 1. Kiểm tra package bắt buộc ===
# getent KHÔNG bắt buộc: Termux không cung cấp nó (util-linux không kèm),
# và nó chỉ dùng để đặt tên nhóm — `id -G` đã phủ mọi GID bằng số.
REQUIRED_CMDS=(wget proot pulseaudio tar termux-fix-shebang)
missing=()
for cmd in "${REQUIRED_CMDS[@]}"; do
	command -v "$cmd" >/dev/null 2>&1 || missing+=("$cmd")
done

if [ "${#missing[@]}" -gt 0 ]; then
	echo "❌ Thiếu package cần thiết: ${missing[*]}"
	echo ""
	# Map command → package name
	pkgs=()
	for cmd in "${missing[@]}"; do
		case "$cmd" in
			termux-fix-shebang) pkgs+=("termux-tools") ;;
			*)                  pkgs+=("$cmd") ;;
		esac
	done
	echo "Chạy: pkg install ${pkgs[*]}"
	echo ""
	read -r -p "Cài ngay? [y/N] " ans
	if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
		pkg install -y "${pkgs[@]}"
	else
		echo "Đã huỷ."
		exit 1
	fi
fi

# === 2. Tải và giải nén rootfs ===
if [ -d "$ROOTFS" ]; then
	echo "Đã có '$FOLDER', bỏ qua tải/giải nén."
else
	if [ ! -f "$TARBALL" ]; then
		echo "Tải rootfs, có thể mất một lúc tuỳ tốc độ mạng."
		echo "⚠️  Tải qua HTTP (không có checksum để xác minh) từ localhost:8000."
		wget -c "http://localhost:8000/ubuntu-rootfs-arm64.tar.gz" -O "$TARBALL"
	fi
	mkdir -p "$ROOTFS"
	echo "Giải nén rootfs, vui lòng chờ."
	if ! proot --link2symlink tar -xf "$TARBALL" -C "$ROOTFS"; then
		echo "❌ Giải nén thất bại — rootfs có thể hỏng. Xoá '$ROOTFS' rồi thử lại."
		exit 1
	fi
fi

# === 3. Fake sysdata (giống proot-distro) ===
mkdir -p "$SYSDATA_DIR/sys_empty"
chmod 700 "$SYSDATA_DIR"

printf '0.12 0.07 0.02 2/165 765\n' > "$SYSDATA_DIR/loadavg"
printf '65534\n' > "$SYSDATA_DIR/sysctl_kernel_overflowuid"
printf '65534\n' > "$SYSDATA_DIR/sysctl_kernel_overflowgid"
printf '40\n' > "$SYSDATA_DIR/sysctl_entry_cap_last_cap"
printf '4096\n' > "$SYSDATA_DIR/sysctl_inotify_max_user_watches"

cat > "$SYSDATA_DIR/stat" << 'SYSEOF'
cpu  1957 0 2877 93280 262 342 254 87 0 0
cpu0 31 0 226 12027 82 10 4 9 0 0
cpu1 45 0 664 11144 21 263 233 12 0 0
cpu2 494 0 537 11283 27 10 3 8 0 0
cpu3 359 0 234 11723 24 26 5 7 0 0
cpu4 295 0 268 11772 10 12 2 12 0 0
cpu5 270 0 251 11833 15 3 1 10 0 0
cpu6 430 0 520 11386 30 8 1 12 0 0
cpu7 30 0 172 12108 50 8 1 13 0 0
intr 127541 38 290 0 0 0 0 4 0 1 0 0 25329 258 0 5777 277 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ctxt 140223
btime 1680020856
processes 772
procs_running 2
procs_blocked 0
softirq 75663 0 5903 6 25375 10774 0 243 11685 0 21677
SYSEOF

cat > "$SYSDATA_DIR/vmstat" << 'VSEOF'
nr_free_pages 1743136
nr_zone_inactive_anon 179281
nr_zone_active_anon 7183
nr_zone_inactive_file 22858
nr_zone_active_file 51328
nr_zone_unevictable 642
nr_zone_write_pending 0
nr_mlock 0
nr_bounce 0
nr_zspages 0
nr_free_cma 0
numa_hit 1259626
numa_miss 0
numa_foreign 0
numa_interleave 720
numa_local 1259626
numa_other 0
nr_inactive_anon 179281
nr_active_anon 7183
nr_inactive_file 22858
nr_active_file 51328
nr_unevictable 642
nr_slab_reclaimable 8091
nr_slab_unreclaimable 7804
nr_isolated_anon 0
nr_isolated_file 0
workingset_nodes 0
workingset_refault_anon 0
workingset_refault_file 0
workingset_activate_anon 0
workingset_activate_file 0
workingset_restore_anon 0
workingset_restore_file 0
workingset_nodereclaim 0
nr_anon_pages 7723
nr_mapped 8905
nr_file_pages 253569
nr_dirty 0
nr_writeback 0
nr_writeback_temp 0
nr_shmem 178741
nr_shmem_hugepages 0
nr_shmem_pmdmapped 0
nr_file_hugepages 0
nr_file_pmdmapped 0
nr_anon_transparent_hugepages 1
nr_vmscan_write 0
nr_vmscan_immediate_reclaim 0
nr_dirtied 0
nr_written 0
nr_throttled_written 0
nr_kernel_misc_reclaimable 0
nr_foll_pin_acquired 0
nr_foll_pin_released 0
nr_kernel_stack 2780
nr_page_table_pages 344
nr_sec_page_table_pages 0
nr_swapcached 0
pgpromote_success 0
pgpromote_candidate 0
nr_dirty_threshold 356564
nr_dirty_background_threshold 178064
pgpgin 890508
pgpgout 0
pswpin 0
pswpout 0
pgalloc_dma 272
pgalloc_dma32 261
pgalloc_normal 1328079
pgalloc_movable 0
pgalloc_device 0
allocstall_dma 0
allocstall_dma32 0
allocstall_normal 0
allocstall_movable 0
allocstall_device 0
pgskip_dma 0
pgskip_dma32 0
pgskip_normal 0
pgskip_movable 0
pgskip_device 0
pgfree 3077011
pgactivate 0
pgdeactivate 0
pglazyfree 0
pgfault 176973
pgmajfault 488
pglazyfreed 0
pgrefill 0
pgreuse 19230
pgsteal_kswapd 0
pgsteal_direct 0
pgsteal_khugepaged 0
pgdemote_kswapd 0
pgdemote_direct 0
pgdemote_khugepaged 0
pgscan_kswapd 0
pgscan_direct 0
pgscan_khugepaged 0
pgscan_direct_throttle 0
pgscan_anon 0
pgscan_file 0
pgsteal_anon 0
pgsteal_file 0
zone_reclaim_failed 0
pginodesteal 0
slabs_scanned 0
kswapd_inodesteal 0
kswapd_low_wmark_hit_quickly 0
kswapd_high_wmark_hit_quickly 0
pageoutrun 0
pgrotated 0
drop_pagecache 0
drop_slab 0
oom_kill 0
numa_pte_updates 0
numa_huge_pte_updates 0
numa_hint_faults 0
numa_hint_faults_local 0
numa_pages_migrated 0
pgmigrate_success 0
pgmigrate_fail 0
thp_migration_success 0
thp_migration_fail 0
thp_migration_split 0
compact_migrate_scanned 0
compact_free_scanned 0
compact_isolated 0
compact_stall 0
compact_fail 0
compact_success 0
compact_daemon_wake 0
compact_daemon_migrate_scanned 0
compact_daemon_free_scanned 0
htlb_buddy_alloc_success 0
htlb_buddy_alloc_fail 0
cma_alloc_success 0
cma_alloc_fail 0
unevictable_pgs_culled 27002
unevictable_pgs_scanned 0
unevictable_pgs_rescued 744
unevictable_pgs_mlocked 744
unevictable_pgs_munlocked 744
unevictable_pgs_cleared 0
unevictable_pgs_stranded 0
thp_fault_alloc 13
thp_fault_fallback 0
thp_fault_fallback_charge 0
thp_collapse_alloc 4
thp_collapse_alloc_failed 0
thp_file_alloc 0
thp_file_fallback 0
thp_file_fallback_charge 0
thp_file_mapped 0
thp_split_page 0
thp_split_page_failed 0
thp_deferred_split_page 1
thp_split_pmd 1
thp_scan_exceed_none_pte 0
thp_scan_exceed_swap_pte 0
thp_scan_exceed_share_pte 0
thp_split_pud 0
thp_zero_page_alloc 0
thp_zero_page_alloc_failed 0
thp_swpout 0
thp_swpout_fallback 0
balloon_inflate 0
balloon_deflate 0
balloon_migrate 0
swap_ra 0
swap_ra_hit 0
ksm_swpin_copy 0
cow_ksm 0
zswpin 0
zswpout 0
direct_map_level2_splits 29
direct_map_level3_splits 0
nr_unstable 0
VSEOF

printf '124.08 932.80\n' > "$SYSDATA_DIR/uptime"
printf 'Linux version 6.17.0-PRoot-Distro (proot@termux) (gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) #1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000\n' > "$SYSDATA_DIR/version"

# === 4. /dev/shm là thư mục sibling (mode 1777), không phải <rootfs>/tmp ===
# proot phân giải nguồn bind theo TÊN khi mount, sau khi mọi kiểm tra đã xong;
# guest đổi <rootfs>/tmp thành symlink sẽ khiến phiên sau mount nhầm thư mục host.
mkdir -p "$SHM_DIR"
chmod 1777 "$SHM_DIR"

# === 5. /etc/hosts và /etc/resolv.conf (THAY THẾ, không append) ===
mkdir -p "$ROOTFS/etc"
cat > "$ROOTFS/etc/hosts" << 'HSEOF'
# IPv4.
127.0.0.1   localhost.localdomain localhost

# IPv6.
::1         localhost.localdomain localhost ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
ff02::3     ip6-allhosts
HSEOF

# Ghi đè hoàn toàn để chạy lại không nhân đôi nameserver.
rm -f "$ROOTFS/etc/resolv.conf"
cat > "$ROOTFS/etc/resolv.conf" << 'RSEOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
RSEOF

# === 6. Cấu hình dpkg / apt ===
mkdir -p "$ROOTFS/etc/profile.d"
mkdir -p "$ROOTFS/etc/dpkg/dpkg.cfg.d"
echo 'force-unsafe-io' > "$ROOTFS/etc/dpkg/dpkg.cfg.d/unsafe-io"
mkdir -p "$ROOTFS/etc/apt/apt.conf.d"
cat > "$ROOTFS/etc/apt/apt.conf.d/99lean" << 'APEOF'
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APEOF

# === 7. chmod id files + đăng ký Android UID/GID (idempotent) ===
# proot-distro chmod 0644 bốn file id để login đọc được passwd/group.
for f in passwd shadow group gshadow; do
	[ -f "$ROOTFS/etc/$f" ] && chmod 0644 "$ROOTFS/etc/$f"
done

termux_uid="$(id -u)"
termux_gid="$(id -g)"
termux_user="$(id -un)"
primary_group="$(id -ng)"

# Thêm một dòng vào file nếu chưa có — chạy lại không nhân đôi entry.
append_once() {
	local file="$1" line="$2"
	[ -f "$file" ] || return 0
	grep -qxF "$line" "$file" && return 0
	printf '%s\n' "$line" >> "$file"
}

append_once "$ROOTFS/etc/passwd" "aid_${termux_user}:x:${termux_uid}:${termux_gid}:Termux:/:/sbin/nologin"
append_once "$ROOTFS/etc/shadow" "aid_${termux_user}:*:18446:0:99999:7:::"
append_once "$ROOTFS/etc/group" "aid_${primary_group}:x:${termux_gid}:root,aid_${termux_user}"
[ -f "$ROOTFS/etc/gshadow" ] && append_once "$ROOTFS/etc/gshadow" "aid_${primary_group}:*::root,aid_${termux_user}"

# Nhóm phụ (dedup theo gid).
# Phase 1: đặt tên nhóm qua getent nếu có (getent không bắt buộc trên Termux).
seen_gids=" $termux_gid "
if command -v getent >/dev/null 2>&1; then
	for gname in $(id -nG 2>/dev/null); do
		[ "$gname" = "$primary_group" ] && continue
		gid="$(getent group "$gname" 2>/dev/null | cut -d: -f3)"
		[ -n "$gid" ] || continue
		case "$seen_gids" in *" $gid "*) continue ;; esac
		seen_gids="$seen_gids$gid "
		append_once "$ROOTFS/etc/group" "aid_${gname}:x:${gid}:root,aid_${termux_user}"
		[ -f "$ROOTFS/etc/gshadow" ] && append_once "$ROOTFS/etc/gshadow" "aid_${gname}:*::root,aid_${termux_user}"
	done
fi
# Phase 2: các GID chưa đặt tên (nhóm đặc thù Android) — dùng số.
for gid in $(id -G 2>/dev/null); do
	case "$seen_gids" in *" $gid "*) continue ;; esac
	seen_gids="$seen_gids$gid "
	append_once "$ROOTFS/etc/group" "aid_${gid}:x:${gid}:root,aid_${termux_user}"
	[ -f "$ROOTFS/etc/gshadow" ] && append_once "$ROOTFS/etc/gshadow" "aid_${gid}:*::root,aid_${termux_user}"
done

# === 8. profile.d snippet (sinh động, giống proot-distro) ===
# Login shell source /etc/profile nên mất biến do proot truyền; snippet này
# re-export để `su - user` vẫn giữ. Bỏ qua biến per-session và proot-internal.
LEGACY_SNIPPET="$ROOTFS/etc/profile.d/termux-prefix.sh"
[ -e "$LEGACY_SNIPPET" ] && rm -f "$LEGACY_SNIPPET"

SNIPPET="$ROOTFS/etc/profile.d/termux-profile.sh"
PROFILE_PAIRS=(
	"LANG=C.UTF-8"
	"TZ=Asia/Ho_Chi_Minh"
	"MOZ_FAKE_NO_SANDBOX=1"
	"PULSE_SERVER=127.0.0.1"
	"PD_CONTAINER=$FOLDER"
	"container=proot-distro"
)
for _e in ANDROID_ART_ROOT ANDROID_DATA ANDROID_I18N_ROOT ANDROID_ROOT \
          ANDROID_RUNTIME_ROOT ANDROID_TZDATA_ROOT BOOTCLASSPATH \
          DEX2OATBOOTCLASSPATH EXTERNAL_STORAGE; do
	if _v="$(env_value "$_e")"; then
		[ -n "$_v" ] && PROFILE_PAIRS+=("$_e=$_v")
	fi
done

{
	# Không export PATH (giữ nguyên baseline trong env của proot, không chèn
	# bin Termux) — chỉ re-export các biến bên dưới.
	for pair in "${PROFILE_PAIRS[@]}"; do
		key="${pair%%=*}"
		val="${pair#*=}"
		# Tên biến không hợp lệ (space, ;, quote…) sẽ làm hỏng snippet khi
		# /etc/profile source nó — bỏ qua thay vì ghi dòng phá mọi shell sau.
		[[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
		escaped="${val//\'/\'\\\'\'}"
		printf "export %s='%s'\n" "$key" "$escaped"
	done
} > "$SNIPPET"
chmod 644 "$SNIPPET"

# === 9. Sinh launch script ===
bin="start-ubuntu.sh"
echo "Đang ghi launch script..."
# Heredoc dùng 'EOM' (không expand biến), nên các giá trị phụ thuộc môi trường
# được ghi dưới dạng placeholder @FOLDER@/@TERMUX_PREFIX@/@TERMUX_HOME@ và
# thay bằng sed ngay sau khi ghi.
cat > "$SCRIPT_DIR/$bin" << 'EOM'
#!/data/data/com.termux/files/usr/bin/bash
# start-ubuntu.sh — sinh bởi ubuntu.sh. Chạy container Ubuntu rootless.
set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOTFS="$SCRIPT_DIR/@FOLDER@"
SYSDATA_DIR="$SCRIPT_DIR/@FOLDER@.sysdata"
SHM_DIR="$SCRIPT_DIR/@FOLDER@.shm"

# In giá trị biến có tên $1 nếu đã set; trả về 1 nếu chưa set. An toàn với
# `set -u` — khác ${!name} trực tiếp (báo lỗi "invalid indirect expansion").
env_value() {
	declare -p "$1" >/dev/null 2>&1 || return 1
	printf '%s' "${!1}"
}

# --- Thư mục host-side (mode đặt trên thư mục thật) ---
mkdir -p "$ROOTFS/.l2s"
mkdir -p "$ROOTFS/tmp" && chmod 1777 "$ROOTFS/tmp"
mkdir -p "$ROOTFS/tmp/claude-messaging" && chmod 0700 "$ROOTFS/tmp/claude-messaging"
# /dev/shm lấy từ thư mục sibling của rootfs, không phải <rootfs>/tmp.
mkdir -p "$SHM_DIR" && chmod 1777 "$SHM_DIR"

UNAME_M="$(uname -m 2>/dev/null || echo aarch64)"

pulseaudio --start 2>/dev/null || true
unset LD_PRELOAD

# --- env cho proot (đặt trong env của proot, không dùng env -i cho guest) ---
env=()
env+=(HOME=/root)
env+=(PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games)
env+=(USER=root)
env+=(TERM=xterm-256color)
env+=(LANG=C.UTF-8)
env+=(COLORTERM=truecolor)
env+=(TZ=Asia/Ho_Chi_Minh)
env+=(MOZ_FAKE_NO_SANDBOX=1)
env+=(PULSE_SERVER=127.0.0.1)
env+=(PROOT_L2S_DIR="$ROOTFS/.l2s")
env+=(PROOT_NO_SECCOMP=1)
# Identity: cho guest biết nó đang chạy ở đâu.
env+=(PD_CONTAINER=@FOLDER@)
env+=(container=proot-distro)
# Passthrough biến debug proot do người dùng đặt (chỉ khi có giá trị).
for _v in PROOT_VERBOSE PROOT_DBG_STOPS; do
	if _val="$(env_value "$_v")"; then
		[ -n "$_val" ] && env+=("$_v=$_val")
	fi
done
# Android host vars.
for _e in ANDROID_ART_ROOT ANDROID_DATA ANDROID_I18N_ROOT ANDROID_ROOT \
          ANDROID_RUNTIME_ROOT ANDROID_TZDATA_ROOT BOOTCLASSPATH \
          DEX2OATBOOTCLASSPATH EXTERNAL_STORAGE; do
	if _val="$(env_value "$_e")"; then
		[ -n "$_val" ] && env+=("$_e=$_val")
	fi
done

# --- proot args ---
p_args=("$(command -v proot)")
p_args+=(--kill-on-exit)
p_args+=(--link2symlink)
p_args+=(--sysvipc)
p_args+=(-L)
p_args+=(--change-id=0:0)
p_args+=(--rootfs="$ROOTFS")
p_args+=(--cwd=/root)
p_args+=(--bind=/dev)
p_args+=(--bind=/dev/urandom:/dev/random)
[ ! -e /dev/fd ] && p_args+=(--bind=/proc/self/fd:/dev/fd)
[ ! -e /dev/stdin ] && p_args+=(--bind=/proc/self/fd/0:/dev/stdin)
[ ! -e /dev/stdout ] && p_args+=(--bind=/proc/self/fd/1:/dev/stdout)
[ ! -e /dev/stderr ] && p_args+=(--bind=/proc/self/fd/2:/dev/stderr)
p_args+=(--bind=/proc)
p_args+=(--bind=/sys)
# Fake /proc bindings cho các đường dẫn Android chặn.
for _f in loadavg stat uptime version vmstat; do
	[ ! -r "/proc/$_f" ] && p_args+=(--bind="$SYSDATA_DIR/$_f:/proc/$_f")
done
for _f in "entry_cap_last_cap:kernel/cap_last_cap" "inotify_max_user_watches:fs/inotify/max_user_watches" "kernel_overflowuid:kernel/overflowuid" "kernel_overflowgid:kernel/overflowgid"; do
	_sname="${_f%%:*}"
	_ppath="${_f#*:}"
	[ ! -r "/proc/sys/$_ppath" ] && p_args+=(--bind="$SYSDATA_DIR/sysctl_$_sname:/proc/sys/$_ppath")
done
p_args+=(--bind="$SYSDATA_DIR/sys_empty:/sys/fs/selinux")

# Dalvik/ART caches.
for _d in /data/app /data/dalvik-cache /data/misc/apexdata/com.android.art/dalvik-cache; do
	[ -d "$_d" ] && [ -x "$_d" ] && p_args+=(--bind="$_d")
done
# Shared storage.
if [ -r /storage ]; then
	p_args+=(--bind=/storage)
	[ -r /storage/emulated/0 ] && p_args+=(--bind=/storage/emulated/0:/sdcard)
else
	for _p in /storage/self/primary /storage/emulated/0 /sdcard; do
		if [ -r "$_p" ]; then
			p_args+=(--bind="${_p}:/sdcard")
			break
		fi
	done
fi
# Android system paths.
for _p in /apex /odm /product /system /system_ext /vendor /linkerconfig/ld.config.txt /linkerconfig/com.android.art/ld.config.txt /plat_property_contexts /property_contexts; do
	[ -e "$_p" ] && p_args+=(--bind="$_p")
done
# Termux app paths.
[ -d @TERMUX_PREFIX@/../apps ] && p_args+=(--bind=@TERMUX_PREFIX@/../apps)
p_args+=(--bind=@TERMUX_PREFIX@/../cache)
p_args+=(--bind=@TERMUX_HOME@)
p_args+=(--bind=@TERMUX_PREFIX@)
# /dev/shm = thư mục sibling (KHÔNG phải $ROOTFS/tmp).
p_args+=(--bind="$SHM_DIR:/dev/shm")
# Kernel release (định dạng proot).
HNAME=wizk
kr="\\Linux\\${HNAME}\\6.6.89-wizkvn-100067\\#1 SMP PREEMPT Sat Jul 19 00:22:46 +07 2026\\${UNAME_M}\\localdomain\\-1\\"
p_args+=(--kernel-release="${kr}")
p_args+=(/bin/bash --login)

if [ "$#" -eq 0 ]; then
	exec env -i "${env[@]}" "${p_args[@]}"
else
	exec env -i "${env[@]}" "${p_args[@]}" -c "$(printf '%q ' "$@")"
fi
EOM

# Thay placeholder trong launch script. Escape & và | để tên thư mục lạ không
# phá sed; TERMUX_HOME phải thay trước vì là tiền tố của TERMUX_PREFIX.
# Escape ký tự & và | để an toàn khi nhúng vào biểu thức sed
sed_esc() { printf '%s' "$1" | sed 's/[&|]/\\&/g'; }
_termux_prefix_esc="$(sed_esc "${PREFIX:-/data/data/com.termux/files/usr}")"
_termux_home_esc="$(sed_esc "${HOME:-/data/data/com.termux/files/home}")"
sed -i \
	-e "s|@FOLDER@|$(sed_esc "$FOLDER")|g" \
	-e "s|@TERMUX_HOME@|$_termux_home_esc|g" \
	-e "s|@TERMUX_PREFIX@|$_termux_prefix_esc|g" \
	"$SCRIPT_DIR/$bin"

# === 10. Pulseaudio (giống bản gốc, idempotent) ===
echo "Cấu hình pulseaudio để có âm thanh trong distro."
PA_DEFAULT="$TERMUX_USR/etc/pulse/default.pa"
if [ -f "$PA_DEFAULT" ] && ! grep -q "module-native-protocol-tcp" "$PA_DEFAULT"; then
	echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> "$PA_DEFAULT"
	echo "Đã bật module pulseaudio TCP."
else
	echo "Module đã có hoặc thiếu default.pa — bỏ qua."
fi

PA_DAEMON="$TERMUX_USR/etc/pulse/daemon.conf"
if [ -f "$PA_DAEMON" ] && ! grep -q "^exit-idle-time" "$PA_DAEMON"; then
	echo "exit-idle-time = -1" >> "$PA_DAEMON"
	echo "Đặt pulseaudio timeout = vô hạn."
fi

PA_CLIENT="$TERMUX_USR/etc/pulse/client.conf"
if [ -f "$PA_CLIENT" ] && ! grep -q "^autospawn" "$PA_CLIENT"; then
	echo "autospawn = no" >> "$PA_CLIENT"
	echo "Đã tắt pulseaudio autospawn."
fi

# === 11. Hoàn tất ===
echo "Sửa shebang cho $bin"
termux-fix-shebang "$SCRIPT_DIR/$bin"
chmod +x "$SCRIPT_DIR/$bin"
echo "Xoá tarball để tiết kiệm dung lượng"
rm -f "$TARBALL"
echo "Bạn có thể chạy Ubuntu bằng: ./$bin"
