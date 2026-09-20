#!/data/data/com.termux/files/usr/bin/bash

# === Check required packages ===
missing=()
for cmd in wget proot pulseaudio tar termux-fix-shebang; do
	if ! command -v "$cmd" &>/dev/null; then
		missing+=("$cmd")
	fi
done

if [ ${#missing[@]} -gt 0 ]; then
	echo "❌ Missing required packages: ${missing[*]}"
	echo ""
	# Map command → package name
	pkgs=()
	for cmd in "${missing[@]}"; do
		case "$cmd" in
			termux-fix-shebang) pkgs+=("termux-tools") ;;
			getent)             pkgs+=("util-linux") ;;
			*)                  pkgs+=("$cmd") ;;
		esac
	done
	echo "Run: pkg install ${pkgs[*]}"
	echo ""
	read -p "Install now? [y/N] " ans
	if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
		pkg install -y "${pkgs[@]}"
	else
		echo "Aborted."
		exit 1
	fi
fi

folder=SysUbuntu
if [ -d "$folder" ]; then
	first=1
	echo "skipping downloading"
fi
tarball="ubuntu-rootfs.tar.gz"
if [ "$first" != 1 ];then
	if [ ! -f $tarball ]; then
		echo "Download Rootfs, this may take a while base on your internet speed."
		case `dpkg --print-architecture` in
		aarch64)
			archurl="arm64" ;;
		arm)
			archurl="armhf" ;;
		amd64)
			archurl="amd64" ;;
		x86_64)
			archurl="amd64" ;;	
		i*86)
			archurl="i386" ;;
		x86)
			archurl="i386" ;;
		*)
			echo "unknown architecture"; exit 1 ;;
		esac
		wget -c "http://localhost:8000/ubuntu-rootfs-${archurl}.tar.gz" -O $tarball
	fi
	cur=`pwd`
	mkdir -p "$folder"
	cd "$folder"
	echo "Decompressing Rootfs, please be patient."
	proot --link2symlink tar -xf ${cur}/${tarball}||:
	cd "$cur"
fi

# === Fake sysdata (like proot-distro) ===
sysdata_dir="${folder}.sysdata"
mkdir -p "$sysdata_dir"
mkdir -p "$sysdata_dir/sys_empty"
chmod 700 "$sysdata_dir"

echo "0.12 0.07 0.02 2/165 765" > "$sysdata_dir/loadavg"
echo "65534" > "$sysdata_dir/sysctl_kernel_overflowuid"
echo "65534" > "$sysdata_dir/sysctl_kernel_overflowgid"
echo "40" > "$sysdata_dir/sysctl_entry_cap_last_cap"
echo "4096" > "$sysdata_dir/sysctl_inotify_max_user_watches"

cat > "$sysdata_dir/stat" << 'SYSEOF'
cpu  1957 0 2877 93280 262 342 254 87 0 0
cpu0 31 0 226 12027 82 10 4 9 0 0
cpu1 45 0 664 11144 21 263 233 12 0 0
cpu2 494 0 537 11283 27 10 3 8 0 0
cpu3 359 0 234 11723 24 26 5 7 0 0
cpu4 295 0 268 11772 10 12 2 12 0 0
cpu5 270 0 251 11833 15 3 1 10 0 0
cpu6 430 0 520 11386 30 8 1 12 0 0
cpu7 30 0 172 12108 50 8 1 13 0 0
intr 127541 38 290 0 0 0 0 4 0 1 0 0 25329 258 0 5777 277 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
ctxt 140223
btime 1680020856
processes 772
procs_running 2
procs_blocked 0
softirq 75663 0 5903 6 25375 10774 0 243 11685 0 21677
SYSEOF

cat > "$sysdata_dir/vmstat" << 'VSEOF'
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

echo "124.08 932.80" > "$sysdata_dir/uptime"
echo "Linux version 6.17.0-PRoot-Distro (proot@termux) (gcc (GCC) 13.3.0, GNU ld (GNU Binutils) 2.42) #1 SMP PREEMPT_DYNAMIC Fri, 10 Oct 2025 00:00:00 +0000" > "$sysdata_dir/version"

# === /etc/hosts ===
cat > "$folder/etc/hosts" << 'HSEOF'
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

mkdir -p "$folder/etc/profile.d"
mkdir -p "$folder/etc/dpkg/dpkg.cfg.d"
echo 'force-unsafe-io' > "$folder/etc/dpkg/dpkg.cfg.d/unsafe-io"

bin=start-ubuntu.sh
echo "writing launch script"
cat > $bin <<- EOM
#!/data/data/com.termux/files/usr/bin/bash
SCRIPT_DIR="\$(cd \$(dirname \$0) && pwd)"
ROOTFS="\$SCRIPT_DIR/${folder}"
sysdata_dir="\$SCRIPT_DIR/${folder}.sysdata"

pulseaudio --start
unset LD_PRELOAD

mkdir -p "\$ROOTFS/.l2s"
mkdir -p "\$ROOTFS/tmp" && chmod 1777 "\$ROOTFS/tmp"
mkdir -p "\$ROOTFS/tmp/claude-messaging" && chmod 0700 "\$ROOTFS/tmp/claude-messaging"

# Build env for proot (like proot-distro's child_env — set in proot's env, not in guest via env -i)
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
env+=(PROOT_L2S_DIR="\$ROOTFS/.l2s")
env+=(PROOT_NO_SECCOMP=1)
# Android env vars from host
for _e in ANDROID_ART_ROOT ANDROID_DATA ANDROID_I18N_ROOT ANDROID_ROOT ANDROID_RUNTIME_ROOT ANDROID_TZDATA_ROOT BOOTCLASSPATH DEX2OATBOOTCLASSPATH EXTERNAL_STORAGE; do
	[ -n "\${!_e}" ] && env+=("\$_e=\${!_e}")
done

# Build proot args array (preserves backslashes in kernel-release)
p_args=($(command -v proot))
p_args+=(--kill-on-exit)
p_args+=(--link2symlink)
p_args+=(--sysvipc)
p_args+=(-L)
p_args+=(--change-id=0:0)
p_args+=(--rootfs="\$ROOTFS")
p_args+=(--cwd=/root)
p_args+=(--bind=/dev)
p_args+=(--bind=/dev/urandom:/dev/random)
if [ ! -e /dev/fd ]; then p_args+=(--bind=/proc/self/fd:/dev/fd); fi
if [ ! -e /dev/stdin ]; then p_args+=(--bind=/proc/self/fd/0:/dev/stdin); fi
if [ ! -e /dev/stdout ]; then p_args+=(--bind=/proc/self/fd/1:/dev/stdout); fi
if [ ! -e /dev/stderr ]; then p_args+=(--bind=/proc/self/fd/2:/dev/stderr); fi
p_args+=(--bind=/proc)
p_args+=(--bind=/sys)
# Fake /proc bindings for Android restricted paths
for _f in loadavg stat uptime version vmstat; do
	if [ ! -r "/proc/\$_f" ]; then
		p_args+=(--bind="\$sysdata_dir/\$_f:/proc/\$_f")
	fi
done
for _f in "entry_cap_last_cap:kernel/cap_last_cap" "inotify_max_user_watches:fs/inotify/max_user_watches" "kernel_overflowuid:kernel/overflowuid" "kernel_overflowgid:kernel/overflowgid"; do
	_sname="\${_f%%:*}"
	_ppath="\${_f#*:}"
	if [ ! -r "/proc/sys/\$_ppath" ]; then
		p_args+=(--bind="\$sysdata_dir/sysctl_\$_sname:/proc/sys/\$_ppath")
	fi
done

p_args+=(--bind="\$sysdata_dir/sys_empty:/sys/fs/selinux")

# Dalvik/ART caches
for _d in /data/app /data/dalvik-cache /data/misc/apexdata/com.android.art/dalvik-cache; do
	if [ -d "\$_d" ] && [ -x "\$_d" ]; then
		p_args+=(--bind="\$_d")
	fi
done
# Storage
if [ -r /storage ]; then
	p_args+=(--bind=/storage)
	if [ -r /storage/emulated/0 ]; then
		p_args+=(--bind=/storage/emulated/0:/sdcard)
#p_args+=(--bind=/storage/emulated/0:/mnt/sdcard)
	fi
else
	for _p in /storage/self/primary /storage/emulated/0 /sdcard; do
		if [ -r "\$_p" ]; then
#			p_args+=(--bind="\$_p":/mnt/sdcard)
			p_args+=(--bind="\$_p":/sdcard)
#			p_args+=(--bind="\$_p":/storage/emulated/0)
#			p_args+=(--bind="\$_p":/storage/self/primary)
			break
		fi
	done
fi
# Android system paths
for _p in /apex /odm /product /system /system_ext /vendor /linkerconfig/ld.config.txt /linkerconfig/com.android.art/ld.config.txt /plat_property_contexts /property_contexts; do
	if [ -e "\$_p" ]; then
		p_args+=(--bind="\$_p")
	fi
done
# Termux app paths
if [ -d /data/data/com.termux/files/apps ]; then
	p_args+=(--bind=/data/data/com.termux/files/apps)
fi
p_args+=(--bind=/data/data/com.termux/cache)
p_args+=(--bind=/data/data/com.termux/files/home)
p_args+=(--bind=/data/data/com.termux/files/usr)
# /dev/shm (tmp inside rootfs)
p_args+=(--bind="\$ROOTFS/tmp:/dev/shm")
# Kernel release (proot format)
HNAME=wizk
UNAME_M=\$(uname -m 2>/dev/null || echo aarch64)
kr="\\\\Linux\\\\\${HNAME}\\\\6.6.89-wizkvn-100067\\\\#1 SMP PREEMPT Sat Jul 19 00:22:46 +07 2026\\\\\${UNAME_M}\\\\localdomain\\\\-1\\\\"
p_args+=(--kernel-release="\${kr}")
p_args+=(/bin/bash --login)

if [ \$# -eq 0 ]; then
	exec env -i "\${env[@]}" "\${p_args[@]}"
else
	exec env -i "\${env[@]}" "\${p_args[@]}" -c "\$*"
fi
EOM

echo "Setting up pulseaudio so you can have music in distro."

if grep -q "anonymous" ~/../usr/etc/pulse/default.pa;then
    echo "module already present"
else
    echo "load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" >> ~/../usr/etc/pulse/default.pa
fi

# Dynamic Android UID/GID registration (like proot-distro)
termux_uid=$(id -u)
termux_gid=$(id -g)
termux_user=$(id -un)

echo "aid_${termux_user}:x:${termux_uid}:${termux_gid}:Termux:/:/sbin/nologin" >> "$folder/etc/passwd"
echo "aid_${termux_user}:*:18446:0:99999:7:::" >> "$folder/etc/shadow"

# Primary group
primary_group=$(id -ng)
echo "aid_${primary_group}:x:${termux_gid}:root,aid_${termux_user}" >> "$folder/etc/group"
[ -f "$folder/etc/gshadow" ] && echo "aid_${primary_group}:*::root,aid_${termux_user}" >> "$folder/etc/gshadow"

# Supplementary groups (deduplicated)
# Phase 1: groups resolvable by name
seen_gids=""
for gname in $(id -nG 2>/dev/null); do
	[ "$gname" = "$primary_group" ] && continue
	gid=$(getent group "$gname" 2>/dev/null | cut -d: -f3)
	[ -z "$gid" ] && continue
	case "$seen_gids" in
		*"$gid"*) continue ;;
	esac
	seen_gids="$seen_gids $gid"
	echo "aid_${gname}:x:${gid}:root,aid_${termux_user}" >> "$folder/etc/group"
	[ -f "$folder/etc/gshadow" ] && echo "aid_${gname}:*::root,aid_${termux_user}" >> "$folder/etc/gshadow"
done
# Phase 2: numeric GIDs not resolved above (Android-specific groups)
for gid in $(id -G 2>/dev/null); do
	[ "$gid" = "$termux_gid" ] && continue
	case "$seen_gids" in
		*"$gid"*) continue ;;
	esac
	seen_gids="$seen_gids $gid"
	echo "aid_${gid}:x:${gid}:root,aid_${termux_user}" >> "$folder/etc/group"
	[ -f "$folder/etc/gshadow" ] && echo "aid_${gid}:*::root,aid_${termux_user}" >> "$folder/etc/gshadow"
done
echo "nameserver 8.8.8.8" >> "$folder/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$folder/etc/resolv.conf"
echo 'APT::Install-Recommends "false";' > "$folder/etc/apt/apt.conf.d/99lean"
echo 'APT::Install-Suggests "false";'  >> "$folder/etc/apt/apt.conf.d/99lean"
echo "exit-idle-time = -1" >> ~/../usr/etc/pulse/daemon.conf
echo "Modified pulseaudio timeout to infinite"
echo "autospawn = no" >> ~/../usr/etc/pulse/client.conf
echo "Disabled pulseaudio autospawn"
# === Profile.d injection (like proot-distro) ===
cat > "$folder/etc/profile.d/termux-profile.sh" << 'TPEOF'
#case ":${PATH}:" in
#  *":/data/data/com.termux/files/usr/bin:"*) ;;
#  *) export PATH="${PATH}:/data/data/com.termux/files/usr/bin" ;;
#esac
export PULSE_SERVER=127.0.0.1
export MOZ_FAKE_NO_SANDBOX=1
TPEOF
chmod 644 "$folder/etc/profile.d/termux-profile.sh"
#echo "Injected termux-profile.sh"

echo "fixing shebang of $bin"
termux-fix-shebang $bin
echo "making $bin executable"
chmod +x $bin
echo "removing image for some space"
rm $tarball
echo "You can now launch Ubuntu with the ./${bin} script"
