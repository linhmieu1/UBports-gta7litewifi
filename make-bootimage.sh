#!/bin/bash
set -ex

TMPDOWN=$(realpath $1)
KERNEL_OBJ=$(realpath $2)
RAMDISK=$(realpath $3)
OUT=$(realpath $4)
INSTALL_MOD_PATH="$(realpath $5)"

HERE=$(pwd)
source "${HERE}/deviceinfo"

kernel_arch="${deviceinfo_kernel_arch:-$deviceinfo_arch}"

case "$kernel_arch" in
    aarch64) ARCH="arm64" ;;
    *) ARCH="$kernel_arch" ;;
esac

[ -f "$HERE/ramdisk-recovery.img" ] && RECOVERY_RAMDISK="$HERE/ramdisk-recovery.img"
[ -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ] && RECOVERY_RAMDISK="$HERE/ramdisk-overlay/ramdisk-recovery.img"

case "${deviceinfo_ramdisk_compression:=gzip}" in
    gzip)
        COMPRESSION_CMD="gzip -9"
        ;;
    lz4)
        COMPRESSION_CMD="lz4 -l -9"
        ;;
    *)
        echo "Unsupported deviceinfo_ramdisk_compression value: '$deviceinfo_ramdisk_compression'"
        exit 1
        ;;
esac

if [ -d "$HERE/ramdisk-recovery-overlay" ] && [ -e "$RECOVERY_RAMDISK" ]; then
    rm -rf "$TMPDOWN/ramdisk-recovery"
    mkdir -p "$TMPDOWN/ramdisk-recovery"
    cd "$TMPDOWN/ramdisk-recovery"

    HAS_DYNAMIC_PARTITIONS=false
    [[ "$deviceinfo_kernel_cmdline" == *"systempart=/dev/mapper"* ]] && HAS_DYNAMIC_PARTITIONS=true

    fakeroot -- bash <<EOF
gzip -dc "$RECOVERY_RAMDISK" | cpio -i
cp -r "$HERE/ramdisk-recovery-overlay"/* "$TMPDOWN/ramdisk-recovery"

# Set values in prop.default based on deviceinfo
echo "#" >> prop.default
echo "# added by halium-generic-adaptation-build-tools" >> prop.default
echo "ro.product.brand=$deviceinfo_manufacturer" >> prop.default
echo "ro.product.device=$deviceinfo_codename" >> prop.default
echo "ro.product.manufacturer=$deviceinfo_manufacturer" >> prop.default
echo "ro.product.model=$deviceinfo_name" >> prop.default
echo "ro.product.name=halium_$deviceinfo_codename" >> prop.default
[ "$HAS_DYNAMIC_PARTITIONS" = true ] && echo "ro.boot.dynamic_partitions=true" >> prop.default

find . | cpio -o -H newc | gzip -9 > "$TMPDOWN/ramdisk-recovery.img-merged"
EOF
    if [ ! -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ]; then
        RECOVERY_RAMDISK="$TMPDOWN/ramdisk-recovery.img-merged"
    else
        mv "$HERE/ramdisk-overlay/ramdisk-recovery.img" "$TMPDOWN/ramdisk-recovery.img-original"
        cp "$TMPDOWN/ramdisk-recovery.img-merged" "$HERE/ramdisk-overlay/ramdisk-recovery.img"
    fi
fi

if [ "$deviceinfo_ramdisk_compression" != "gzip" ]; then
    gzip -dc "$RAMDISK" | $COMPRESSION_CMD > "${RAMDISK}.${deviceinfo_ramdisk_compression}"
    RAMDISK="${RAMDISK}.${deviceinfo_ramdisk_compression}"
fi

if [ -d "$HERE/ramdisk-overlay" ]; then
    cp "$RAMDISK" "${RAMDISK}-merged"
    RAMDISK="${RAMDISK}-merged"
    cd "$HERE/ramdisk-overlay"
    find . | cpio -o -H newc | $COMPRESSION_CMD >> "$RAMDISK"

    # Restore unoverlayed recovery ramdisk
    if [ -f "$HERE/ramdisk-overlay/ramdisk-recovery.img" ] && [ -f "$TMPDOWN/ramdisk-recovery.img-original" ]; then
        mv "$TMPDOWN/ramdisk-recovery.img-original" "$HERE/ramdisk-overlay/ramdisk-recovery.img"
    fi
fi

# Create ramdisk for vendor_boot.img
if [ -d "$HERE/vendor-ramdisk-overlay" ]; then
    VENDOR_RAMDISK="$TMPDOWN/ramdisk-vendor_boot.img"
    rm -rf "$TMPDOWN/vendor-ramdisk"
    mkdir -p "$TMPDOWN/vendor-ramdisk"
    cd "$TMPDOWN/vendor-ramdisk"

    if [[ -f "$HERE/vendor-ramdisk-overlay/lib/modules/modules.load" && "$deviceinfo_kernel_disable_modules" != "true" ]]; then
        item_in_array() { local item match="$1"; shift; for item; do [ "$item" = "$match" ] && return 0; done; return 1; }
        modules_dep="$(find "$INSTALL_MOD_PATH"/ -type f -name modules.dep)"
        modules="$(dirname "$modules_dep")" # e.g. ".../lib/modules/5.10.110-gb4d6c7a2f3a6"
        modules_len=${#modules} # e.g. 105
        all_modules="$(find "$modules" -type f -name "*.ko*")"
        module_files=("$modules/modules.alias" "$modules/modules.dep" "$modules/modules.softdep")
        set +x
        while read -r mod; do
            mod_path="$(echo -e "$all_modules" | grep "/${mod%.ko}.ko" || true)" # ".../kernel/.../mod.ko"
            if [ -z "$mod_path" ]; then
                echo "Missing the module file $mod included in modules.load"
                continue
            fi
            mod_path="${mod_path:$((modules_len+1))}" # drop absolute path prefix
            dep_paths="$(sed -n "s|^$mod_path: ||p" "$modules_dep")"
            for mod_file in $mod_path $dep_paths; do # e.g. "kernel/.../mod.ko"
                item_in_array "$modules/$mod_file" "${module_files[@]}" && continue # skip over already processed modules
                module_files+=("$modules/$mod_file")
            done
        done < <(cat "$HERE/vendor-ramdisk-overlay/lib/modules/modules.load"* | sort | uniq)
        set -x
        mkdir -p "$TMPDOWN/vendor-ramdisk/lib/modules"
        cp "${module_files[@]}" "$TMPDOWN/vendor-ramdisk/lib/modules"

        # rewrite modules.dep for GKI /lib/modules/*.ko structure
        set +x
        while read -r line; do
            printf '/lib/modules/%s:' "$(basename ${line%:*})"
            deps="${line#*:}"
            if [ "$deps" ]; then
                for m in $(basename -a $deps); do
                    printf ' /lib/modules/%s' "$m"
                done
            fi
            echo
        done < "$modules/modules.dep" | tee "$TMPDOWN/vendor-ramdisk/lib/modules/modules.dep"
        set -x
    fi

    cp -r "$HERE/vendor-ramdisk-overlay"/* "$TMPDOWN/vendor-ramdisk"

    find . | cpio -o -H newc | $COMPRESSION_CMD > "$VENDOR_RAMDISK"
fi

if [ -n "$deviceinfo_kernel_image_name" ]; then
    KERNEL="$KERNEL_OBJ/arch/$ARCH/boot/$deviceinfo_kernel_image_name"
    # Handle lz4 compression if needed
    if [ "$deviceinfo_kernel_image_name" == "Image.lz4" ] && [ ! -e "$KERNEL" ]; then
        lz4 -l -9 "$KERNEL_OBJ/arch/$ARCH/boot/Image" "$KERNEL"
    fi
else
    # Autodetect kernel image name for boot.img
    if [ "$deviceinfo_bootimg_header_version" -ge 2 ]; then
        IMAGE_LIST="Image.gz Image"
    else
        IMAGE_LIST="Image.gz-dtb Image.gz Image"
    fi

    for image in $IMAGE_LIST; do
        if [ -e "$KERNEL_OBJ/arch/$ARCH/boot/$image" ]; then
            KERNEL="$KERNEL_OBJ/arch/$ARCH/boot/$image"
            break
        fi
    done
fi

if [ -n "$deviceinfo_bootimg_prebuilt_dtb" ]; then
    DTB="$HERE/$deviceinfo_bootimg_prebuilt_dtb"
elif [ -n "$deviceinfo_dtb" ]; then
    DTB="$KERNEL_OBJ/../$deviceinfo_codename.dtb"
    PREFIX=$KERNEL_OBJ/arch/$ARCH/boot/dts/
    DTBS="$PREFIX${deviceinfo_dtb// / $PREFIX}"
    if [ -n "$deviceinfo_dtb_has_dt_table" ] && $deviceinfo_dtb_has_dt_table; then
        echo "Appending DTB partition header to DTB"
        python2 "$TMPDOWN/libufdt/utils/src/mkdtboimg.py" create "$DTB" $DTBS --id="${deviceinfo_dtb_id:-0x00000000}" --rev="${deviceinfo_dtb_rev:-0x00000000}" --custom0="${deviceinfo_dtb_custom0:-0x00000000}" --custom1="${deviceinfo_dtb_custom1:-0x00000000}" --custom2="${deviceinfo_dtb_custom2:-0x00000000}" --custom3="${deviceinfo_dtb_custom3:-0x00000000}"
    else
        cat $DTBS > $DTB
    fi
fi

if [ -n "$deviceinfo_bootimg_prebuilt_dt" ]; then
    DT="$HERE/$deviceinfo_bootimg_prebuilt_dt"
elif [ -n "$deviceinfo_bootimg_dt" ]; then
    PREFIX=$KERNEL_OBJ/arch/$ARCH/boot
    DT="$PREFIX/$deviceinfo_bootimg_dt"
fi

if [ -n "$deviceinfo_prebuilt_dtbo" ]; then
    DTBO="$HERE/$deviceinfo_prebuilt_dtbo"
elif [ -n "$deviceinfo_dtbo" ]; then
    DTBO="$(dirname "$OUT")/dtbo.img"
fi

MKBOOTIMG="$TMPDOWN/android_system_tools_mkbootimg/mkbootimg.py"
EXTRA_ARGS=""
EXTRA_VENDOR_ARGS=""
INIT_BOOT_IMAGE=""

if [ "$deviceinfo_bootimg_header_version" -le 2 ]; then
    EXTRA_ARGS+=" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize"
else
    EXTRA_VENDOR_ARGS+=" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize --dtb $DTB --dtb_offset $deviceinfo_flash_offset_dtb"
fi

if [ "$deviceinfo_bootimg_header_version" -eq 4 ]; then
    if [ -n "$deviceinfo_vendor_bootconfig_path" ]; then
        EXTRA_VENDOR_ARGS+=" --vendor_bootconfig ${HERE}/$deviceinfo_vendor_bootconfig_path"
    fi
fi

if [ "$deviceinfo_bootimg_header_version" -eq 0 ] && [ -n "$DT" ]; then
    EXTRA_ARGS+=" --dt $DT"
fi

if [ "$deviceinfo_bootimg_header_version" -eq 2 ]; then
    EXTRA_ARGS+=" --dtb $DTB --dtb_offset $deviceinfo_flash_offset_dtb"
fi

if [ -n "$deviceinfo_bootimg_board" ]; then
    EXTRA_ARGS+=" --board $deviceinfo_bootimg_board"
fi

if [ "$deviceinfo_bootimg_header_version" -le 2 ]; then
    "$MKBOOTIMG" --kernel "$KERNEL" --ramdisk "$RAMDISK" --cmdline "$deviceinfo_kernel_cmdline" --header_version $deviceinfo_bootimg_header_version -o "$OUT" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS
else
    if ([ -n "$deviceinfo_bootimg_has_init_boot_partition" ] && [ "$deviceinfo_bootimg_has_init_boot_partition" == "true" ]) || [ -n "$deviceinfo_init_boot_partition_size" ]; then
        INIT_BOOT_IMAGE="$(dirname "$OUT")/init_$(basename "$OUT")"
        "$MKBOOTIMG" --kernel "$KERNEL" --header_version $deviceinfo_bootimg_header_version -o "$OUT" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS
        "$MKBOOTIMG" --ramdisk "$RAMDISK" --header_version $deviceinfo_bootimg_header_version -o "$INIT_BOOT_IMAGE"
    else
        "$MKBOOTIMG" --kernel "$KERNEL" --ramdisk "$RAMDISK" --header_version $deviceinfo_bootimg_header_version -o "$OUT" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS
    fi

    if [ -n "$VENDOR_RAMDISK" ]; then
        VENDOR_RAMDISK_ARGS=()
        if [ "$deviceinfo_bootimg_header_version" -eq 3 ]; then
            VENDOR_RAMDISK_ARGS=(--vendor_ramdisk "$VENDOR_RAMDISK")
        else
            VENDOR_RAMDISK_ARGS=(--ramdisk_type platform --ramdisk_name '' --vendor_ramdisk_fragment "$VENDOR_RAMDISK")
        fi
        "$MKBOOTIMG" "${VENDOR_RAMDISK_ARGS[@]}" --vendor_cmdline "$deviceinfo_kernel_cmdline" --header_version $deviceinfo_bootimg_header_version --vendor_boot "$(dirname "$OUT")/vendor_$(basename "$OUT")" $EXTRA_VENDOR_ARGS
    fi
fi

if [ -n "$deviceinfo_bootimg_partition_size" ]; then
    if [ "$deviceinfo_bootimg_tailtype" == "SEAndroid" ]
    then
        printf 'SEANDROIDENFORCE' >> "$OUT"
    else
        EXTRA_ARGS=""
        [ -f "$HERE/rsa4096_boot.pem" ] && EXTRA_ARGS=" --key $HERE/rsa4096_boot.pem --algorithm SHA256_RSA4096"
        python3 "$TMPDOWN/avb/avbtool" add_hash_footer --image "$OUT" --partition_name boot --partition_size $deviceinfo_bootimg_partition_size $EXTRA_ARGS

        if [ -n "$deviceinfo_bootimg_append_vbmeta" ] && $deviceinfo_bootimg_append_vbmeta; then
            python3 "$TMPDOWN/avb/avbtool" append_vbmeta_image --image "$OUT" --partition_size "$deviceinfo_bootimg_partition_size" --vbmeta_image "$TMPDOWN/vbmeta.img"
        fi
    fi
fi

if [ -n "$INIT_BOOT_IMAGE" ]; then
    init_partition_size="${deviceinfo_init_boot_partition_size:-8388608}"
    python3 "$TMPDOWN/avb/avbtool" add_hash_footer --image "$INIT_BOOT_IMAGE" --partition_name init_boot --partition_size $init_partition_size $INIT_BOOT_EXTRA_ARGS
fi

if [ -n "$deviceinfo_has_recovery_partition" ] && $deviceinfo_has_recovery_partition; then
    RECOVERY="$(dirname "$OUT")/recovery.img"
    EXTRA_ARGS=""

    if [ "$deviceinfo_bootimg_header_version" -ge 2 ]; then
        EXTRA_ARGS+=" --header_version $deviceinfo_bootimg_header_version --dtb $DTB --dtb_offset $deviceinfo_flash_offset_dtb"
    fi

    if [ "$deviceinfo_bootimg_header_version" -eq 0 ] && [ -n "$DT" ]; then
        EXTRA_ARGS+=" --header_version 0 --dt $DT"
    fi

    if [ "$deviceinfo_bootimg_header_version" -le 2 ] && [ -n "$DTBO" ]; then
        EXTRA_ARGS+=" --recovery_dtbo $DTBO"
    fi

    "$MKBOOTIMG" --kernel "$KERNEL" --ramdisk "$RECOVERY_RAMDISK" --base $deviceinfo_flash_offset_base --kernel_offset $deviceinfo_flash_offset_kernel --ramdisk_offset $deviceinfo_flash_offset_ramdisk --second_offset $deviceinfo_flash_offset_second --tags_offset $deviceinfo_flash_offset_tags --pagesize $deviceinfo_flash_pagesize --cmdline "$deviceinfo_kernel_cmdline" -o "$RECOVERY" --os_version $deviceinfo_bootimg_os_version --os_patch_level $deviceinfo_bootimg_os_patch_level $EXTRA_ARGS

    if [ -n "$deviceinfo_recovery_partition_size" ]; then
        EXTRA_ARGS=""
        if [ "$deviceinfo_bootimg_tailtype" == "SEAndroid" ]
        then
            printf 'SEANDROIDENFORCE' >> "$RECOVERY"
        else
            [ -f "$HERE/rsa4096_recovery.pem" ] && EXTRA_ARGS=" --key $HERE/rsa4096_recovery.pem --algorithm SHA256_RSA4096"
            python3 "$TMPDOWN/avb/avbtool" add_hash_footer --image "$RECOVERY" --partition_name recovery --partition_size $deviceinfo_recovery_partition_size $EXTRA_ARGS
        fi
    fi
fi
