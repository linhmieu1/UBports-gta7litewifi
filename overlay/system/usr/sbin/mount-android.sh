#!/bin/bash

# RW root
mount -o remount,rw /

# A/B slot detect
ab_slot_suffix=$(grep -o 'androidboot\.slot_suffix=..' /proc/cmdline | cut -d "=" -f2)
[ ! -z "$ab_slot_suffix" ] && echo "A/B slot detected: $ab_slot_suffix"

find_partition_path() {
    label=$1
    path="/dev/$label"
    for dir in by-partlabel by-name by-label by-path by-uuid by-partuuid by-id; do
        if [ -e "/dev/disk/$dir/$label$ab_slot_suffix" ]; then
            path="/dev/disk/$dir/$label$ab_slot_suffix"
            break
        elif [ -e "/dev/disk/$dir/$label" ]; then
            path="/dev/disk/$dir/$label"
            break
        fi
    done
    echo $path
}

parse_mount_flags() {
    org_options="$1"
    options=""
    for i in $(echo $org_options | tr "," "\n"); do
        [[ "$i" =~ "context" ]] && continue
        options+=$i","
    done
    options=${options%?}
    echo $options
}

echo "=== Mount Android partitions ==="

# Mount system
if ! mountpoint -q /android/system; then
    mkdir -p /android/system
    system_path=$(find_partition_path "system")
    echo "Mounting $system_path -> /android/system"
    mount -o ro "$system_path" /android/system || echo "FAIL system mount"
fi

# Mount vendor
if ! mountpoint -q /android/vendor; then
    mkdir -p /android/vendor
    vendor_path=$(find_partition_path "vendor")
    echo "Mounting $vendor_path -> /android/vendor"
    mount -o ro "$vendor_path" /android/vendor || echo "FAIL vendor mount"
fi

# DEBUG
ls /android/system/lib64 2>/dev/null | head || echo "system lib64 missing"
ls /android/vendor/lib64 2>/dev/null | head || echo "vendor lib64 missing"

# Bind for LXC
mkdir -p /var/lib/lxc/android/rootfs/system
mkdir -p /var/lib/lxc/android/rootfs/vendor

mount --bind /android/system /var/lib/lxc/android/rootfs/system
mount --bind /android/vendor /var/lib/lxc/android/rootfs/vendor

echo "=== Mount done ==="

# APEX
if [ -d "/apex" ]; then
    mount -t tmpfs tmpfs /apex
    for path in "/android/system/apex/com.android.runtime.release" "/android/system/apex/com.android.runtime.debug"; do
        if [ -e "$path" ]; then
            mkdir -p /apex/com.android.runtime
            mount -o bind "$path" /apex/com.android.runtime
            break
        fi
    done
fi

# Bind lib64 vào hybris để mir/libhybris tìm được thư viện Android
HYBRIS_DIR=/usr/lib/aarch64-linux-gnu/hybris
mkdir -p "$HYBRIS_DIR/system_lib64" "$HYBRIS_DIR/vendor_lib64"

if [ -d /android/system/lib64 ]; then
    mount --bind /android/system/lib64 "$HYBRIS_DIR/system_lib64" 2>/dev/null || echo "bind system lib64 failed"
fi

if [ -d /android/vendor/lib64 ]; then
    mount --bind /android/vendor/lib64 "$HYBRIS_DIR/vendor_lib64" 2>/dev/null || echo "bind vendor lib64 failed"
fi

# Export LD_LIBRARY_PATH for processes started later in boot
export LD_LIBRARY_PATH="$HYBRIS_DIR/vendor_lib64:$HYBRIS_DIR/system_lib64:$LD_LIBRARY_PATH"

# Set properties to help Mir choose EGL implementation
setprop ro.hardware.egl rogue
setprop ro.board.platform mt6765
setprop ro.hardware.gralloc rogue

# fstab parse
fstab=$(ls /android/vendor/etc/fstab* 2>/dev/null)

if [ -n "$fstab" ]; then
    cat ${fstab} | while read line; do
        set -- $line
        echo $1 | egrep -q "^#|^$" && continue
        ([ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]) && continue
        ([ "$2" = "/system" ] || [ "$2" = "/vendor" ] || [ "$2" = "/data" ]) && continue

        label=$(echo $1 | awk -F/ '{print $NF}')
        path=$(find_partition_path $label)

        if [ -e "$path" ]; then
            mkdir -p $2
            mount $path $2 -t $3 -o $(parse_mount_flags $4)
        fi
    done
fi
