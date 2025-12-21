#!/bin/bash
# ==============================================================================
# Packaging Module
# ==============================================================================

# Source common functions
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$MODULE_DIR/common.sh"

# Find the built kernel Image
# ✅ UPDATED: 优先从 dist 目录查找，这是 Bazel run --dist_dir 的标准输出位置
find_kernel_image() {
    # Get script directory to find dist output
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    local dist_dir="$script_dir/out/dist"
    
    # First, try dist directory (Bazel run --dist_dir output)
    local image_path=""
    if [ -f "$dist_dir/Image" ]; then
        image_path="$dist_dir/Image"
    elif [ -f "$dist_dir/Image.gz" ]; then
        image_path="$dist_dir/Image.gz"
    fi
    
    # Fallback: Try workspace out directory (legacy support)
    if [ -z "$image_path" ]; then
        image_path=$(find "$WORKSPACE_DIR/out" -name Image 2>/dev/null | head -n 1)
    fi
    
    # Fallback: Try alternative locations
    if [ -z "$image_path" ]; then
        image_path=$(find "$WORKSPACE_DIR" -name Image -path "*/out/*" 2>/dev/null | head -n 1)
    fi
    
    if [ -z "$image_path" ]; then
        error "Could not find built Kernel Image"
        error "Expected locations:"
        error "  - $dist_dir/Image"
        error "  - $dist_dir/Image.gz"
        error "  - $WORKSPACE_DIR/out/Image"
        error "Please run the build first or ensure the build completed successfully."
        exit 1
    fi
    
    echo "$image_path"
}

# Pack Image.gz and boot.img
pack_image_artifacts() {
    log "Packing Image.gz and boot.img..."
    
    # Find kernel image
    IMAGE_PATH=$(find_kernel_image)
    echo "Kernel Image: $IMAGE_PATH"
    
    # Get kernel source root directory (parent of lib directory)
    KERNEL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    OUT_DIR="$KERNEL_ROOT/out"
    
    # Create output directory
    mkdir -p "$OUT_DIR"
    log "Output directory: $OUT_DIR"
    
    # 1. Generate Image.gz
    log "Creating Image.gz..."
    cp "$IMAGE_PATH" "$OUT_DIR/Image"
    gzip -f "$OUT_DIR/Image"
    log "✓ Image.gz created: $OUT_DIR/Image.gz"
    
    # 2. Generate boot.img
    log "Creating boot.img..."
    BOOT_IMG="$OUT_DIR/boot.img"
    
    # Check if mkbootimg is available
    if [ -f "$KERNEL_ROOT/tools/mkbootimg/mkbootimg.py" ]; then
        log "Using local mkbootimg from tools..."
        export PYTHONPATH="$KERNEL_ROOT/tools/mkbootimg:$PYTHONPATH"
        MKBOOTIMG_CMD="python3 $KERNEL_ROOT/tools/mkbootimg/mkbootimg.py"
    elif ! command -v mkbootimg &> /dev/null; then
        warn "mkbootimg not found. Trying to use from Android build tools..."
        # Try to find mkbootimg in common Android locations
        if [ -f "$WORKSPACE_DIR/prebuilts/misc/linux-x86/libufdt/mkbootimg.py" ]; then
            MKBOOTIMG_CMD="python3 $WORKSPACE_DIR/prebuilts/misc/linux-x86/libufdt/mkbootimg.py"
        else
            error "mkbootimg not found. Please install Android build tools or set up mkbootimg."
            exit 1
        fi
    else
        MKBOOTIMG_CMD="mkbootimg"
    fi
    
    # Extract cmdline from defconfig if available
    # Note: For GKI, cmdline is usually provided by bootloader/vendor_boot
    # So we should use empty cmdline or only minimal parameters
    CMDLINE=""
    DEFCONFIG="$KERNEL_ROOT/arch/arm64/configs/gki_defconfig"
    CMDLINE_EXTEND=""
    
    if [ -f "$DEFCONFIG" ]; then
        # Check if CMDLINE_EXTEND is enabled
        if grep -q "^CONFIG_CMDLINE_EXTEND=y" "$DEFCONFIG"; then
            CMDLINE_EXTEND="y"
            log "CONFIG_CMDLINE_EXTEND=y detected - cmdline will be appended by bootloader"
        fi
        
        # Extract CONFIG_CMDLINE value (remove quotes and CONFIG_CMDLINE=)
        CMDLINE=$(grep "^CONFIG_CMDLINE=" "$DEFCONFIG" | sed 's/^CONFIG_CMDLINE="\(.*\)"$/\1/' | head -n 1)
    fi
    
    # For GKI, if CMDLINE_EXTEND is enabled, use empty cmdline (bootloader will append)
    # Otherwise, use cmdline from defconfig
    if [ "$CMDLINE_EXTEND" = "y" ]; then
        CMDLINE=""
        log "Using empty cmdline (CMDLINE_EXTEND=y - bootloader will provide full cmdline)"
    elif [ -z "$CMDLINE" ]; then
        # Use empty cmdline for GKI (safer - let bootloader handle it)
        CMDLINE=""
        log "Using empty cmdline (GKI standard - bootloader/vendor_boot provides cmdline)"
    else
        log "Using cmdline from defconfig: $CMDLINE"
    fi
    
    # Create boot.img with header version 4 (GKI Android 13)
    # GKI boot images typically use:
    # - base: 0x00000000 (ARM64 standard)
    # - pagesize: 4096 (standard for most devices)
    # - cmdline: from defconfig
    log "Creating boot.img with cmdline: $CMDLINE"
    $MKBOOTIMG_CMD \
        --kernel "$IMAGE_PATH" \
        --header_version 4 \
        --pagesize 4096 \
        --base 0x00000000 \
        --cmdline "$CMDLINE" \
        --output "$BOOT_IMG"
    
    # Add AVB hash footer if avbtool is available
    if command -v avbtool &> /dev/null; then
        log "Adding AVB hash footer..."
        IMAGE_SIZE=$(stat -c%s "$BOOT_IMG")
        PADDING=$((2 * 1024 * 1024))  # 2MB
        PARTITION_SIZE=$((IMAGE_SIZE + PADDING))
        avbtool add_hash_footer \
            --image "$BOOT_IMG" \
            --partition_name boot \
            --partition_size "$PARTITION_SIZE"
        log "✓ AVB footer added"
    else
        warn "avbtool not found. boot.img created without AVB footer."
    fi
    
    log "✓ boot.img created: $BOOT_IMG"
}

# Pack anykernel.zip
pack_anykernel() {
    log "Packing anykernel.zip..."
    
    # Find kernel image
    IMAGE_PATH=$(find_kernel_image)
    
    # Get kernel source root directory (parent of lib directory)
    KERNEL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    OUT_DIR="$KERNEL_ROOT/out"
    
    # Create output directory
    mkdir -p "$OUT_DIR"
    
    ANYKERNEL_DIR="$OUT_DIR/anykernel_tmp"
    rm -rf "$ANYKERNEL_DIR"
    mkdir -p "$ANYKERNEL_DIR/META-INF/com/google/android"
    
    # Create update-binary script for AnyKernel
    cat > "$ANYKERNEL_DIR/META-INF/com/google/android/update-binary" <<'EOF'
#!/sbin/sh
# AnyKernel installer script for GKI kernel

if [ -n "$3" ] && [ -f "$3" ]; then
    OUTFD=$1
    ZIPFILE=$3
elif [ -n "$2" ] && [ -f "$2" ]; then
    OUTFD=$1
    ZIPFILE=$2
else
    OUTFD=3
    ZIPFILE="/tmp/anykernel.zip"
fi

# Load configuration from anykernel.sh
# In a real AK3, we source anykernel.sh for variables
DEVICE_CHECK="fuxi"

ui_print() {
    echo "ui_print $1" >&$OUTFD
    echo "ui_print " >&$OUTFD
}

show_banner() {
    ui_print "****************************************"
    ui_print "*        Serein Kernel Installer       *"
    ui_print "****************************************"
    ui_print "  Developer: Serein"
    ui_print "****************************************"
}

log_info() { ui_print " [i] $1"; }
log_step() { ui_print ">>> $1..."; }
log_done() { ui_print " [✓] $1"; }
log_warn() { ui_print " [!] Warning: $1"; }
log_fail() { ui_print " [✗] Error: $1"; }

set_progress() {
    echo "set_progress $1" >&$OUTFD
}

show_banner
set_progress 0.1

# System Information
log_info "Collecting system information..."
DEVICE=$(getprop ro.product.model)
PRODUCT=$(getprop ro.product.device)
SDK=$(getprop ro.build.version.sdk)
SLOT=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "N/A")

[ -z "$DEVICE" ] && DEVICE=$(getprop ro.product.model)
[ -z "$PRODUCT" ] && PRODUCT=$(getprop ro.build.product)

log_info "Device: $DEVICE ($PRODUCT)"
log_info "Active Slot: $SLOT"

# Device Verification
if [ -n "$DEVICE_CHECK" ]; then
    if ! echo "$DEVICE $PRODUCT" | grep -qi "$DEVICE_CHECK"; then
        log_warn "This kernel is designed for $DEVICE_CHECK."
        log_warn "Current device is $PRODUCT."
        ui_print " Proceeding anyway in 3 seconds..."
        sleep 3
    fi
fi

# Extract kernel image
log_step "Extracting kernel image"
set_progress 0.2
TMPDIR=/tmp/anykernel_$$
mkdir -p "$TMPDIR"
cd "$TMPDIR"
unzip -o "$ZIPFILE" "Image" || {
    log_fail "Failed to extract Image from zip"
    exit 1
}

if [ ! -f "$TMPDIR/Image" ]; then
    log_fail "Image not found in zip"
    exit 1
fi
log_done "Kernel extracted successfully"

# Enhanced boot partition detection (boot partition only)
find_boot_partition() {
    local boot_part=""
    local slot_suffix=""
    
    # Helper function to check if path exists (works with symlinks and block devices)
    check_path() {
        local p="$1"
        # Try multiple methods to check if path exists
        if [ -e "$p" ] || [ -L "$p" ] || [ -b "$p" ] || [ -c "$p" ]; then
            return 0
        fi
        # Also try using ls (more reliable in some recovery environments)
        if ls "$p" >/dev/null 2>&1; then
            return 0
        fi
        return 1
    }
    
    # Method 1: Direct check for A/B partitions (boot_a and boot_b) - most reliable
    # Check boot_a first (slot a) - try multiple paths
    for path in \
        "/dev/block/by-name/boot_a" \
        "/dev/block/bootdevice/by-name/boot_a" \
        "/dev/block/platform/*/by-name/boot_a" \
        "/dev/block/platform/*/*/by-name/boot_a"; do
        # Expand wildcards
        for p in $path; do
            if check_path "$p"; then
                boot_part="$p"
                ui_print "Found boot partition: $boot_part"
                echo "$boot_part"
                return 0
            fi
        done
    done
    
    # Check boot_b (slot b) - try multiple paths
    for path in \
        "/dev/block/by-name/boot_b" \
        "/dev/block/bootdevice/by-name/boot_b" \
        "/dev/block/platform/*/by-name/boot_b" \
        "/dev/block/platform/*/*/by-name/boot_b"; do
        # Expand wildcards
        for p in $path; do
            if check_path "$p"; then
                boot_part="$p"
                ui_print "Found boot partition: $boot_part"
                echo "$boot_part"
                return 0
            fi
        done
    done
    
    # Method 2: Use find to search for boot_a or boot_b (A/B partitions)
    if [ -d "/dev/block" ]; then
        # Try boot_a first
        boot_part=$(find /dev/block -name "boot_a" 2>/dev/null | head -n 1)
        if [ -n "$boot_part" ] && check_path "$boot_part"; then
            ui_print "Found boot partition via find: $boot_part"
            echo "$boot_part"
            return 0
        fi
        # Try boot_b
        boot_part=$(find /dev/block -name "boot_b" 2>/dev/null | head -n 1)
        if [ -n "$boot_part" ] && check_path "$boot_part"; then
            ui_print "Found boot partition via find: $boot_part"
            echo "$boot_part"
            return 0
        fi
    fi
    
    # Method 3: Check common by-name paths (non-A/B devices)
    for path in \
        "/dev/block/bootdevice/by-name/boot" \
        "/dev/block/by-name/boot"; do
        if check_path "$path"; then
            boot_part="$path"
            ui_print "Found boot partition: $boot_part"
            echo "$boot_part"
            return 0
        fi
    done
    
    # Method 4: Use find to search for boot (non-A/B)
    if [ -d "/dev/block" ]; then
        boot_part=$(find /dev/block -name "boot" 2>/dev/null | head -n 1)
        if [ -n "$boot_part" ] && check_path "$boot_part"; then
            ui_print "Found boot partition via find: $boot_part"
            echo "$boot_part"
            return 0
        fi
    fi
    
    # Method 5: Try getprop (Android system property) - may not work in all recovery environments
    if command -v getprop &> /dev/null; then
        slot_suffix=$(getprop ro.boot.slot_suffix 2>/dev/null || echo "")
        local boot_dev=$(getprop ro.boot.bootdevice 2>/dev/null || echo "")
        
        if [ -n "$boot_dev" ]; then
            # Try with slot suffix first
            if [ -n "$slot_suffix" ]; then
                boot_part="/dev/block/platform/$boot_dev/by-name/boot${slot_suffix}"
                if check_path "$boot_part"; then
                    ui_print "Found boot partition via getprop: $boot_part"
                    echo "$boot_part"
                    return 0
                fi
            fi
            # Try without slot suffix
            boot_part="/dev/block/platform/$boot_dev/by-name/boot"
            if check_path "$boot_part"; then
                ui_print "Found boot partition via getprop: $boot_part"
                echo "$boot_part"
                return 0
            fi
        fi
    fi
    
    # Method 6: Try platform paths with wildcard expansion
    if [ -d "/dev/block/platform" ]; then
        for plat_dir in /dev/block/platform/*/by-name; do
            if [ -d "$plat_dir" ]; then
                # Check boot_a and boot_b first
                for name in boot_a boot_b boot; do
                    if check_path "$plat_dir/$name"; then
                        boot_part="$plat_dir/$name"
                        ui_print "Found boot partition: $boot_part"
                        echo "$boot_part"
                        return 0
                    fi
                done
            fi
        done
    fi
    
    return 1
}

# Try to use magiskboot if available (most reliable method)
if command -v magiskboot &> /dev/null; then
    log_step "Using magiskboot to repack boot image"
    set_progress 0.3
    
    # Find boot partition using enhanced detection
    BOOT_PARTITION=$(find_boot_partition)
    set_progress 0.4
    
    if [ -z "$BOOT_PARTITION" ]; then
        log_fail "Boot partition not found after multiple attempts"
        exit 1
    fi
    
    # Verify the partition exists
    if [ ! -e "$BOOT_PARTITION" ] && [ ! -L "$BOOT_PARTITION" ] && [ ! -b "$BOOT_PARTITION" ]; then
        log_fail "Boot partition not accessible: $BOOT_PARTITION"
        exit 1
    fi
    
    log_info "Target partition: $BOOT_PARTITION"
    
    log_step "Backing up current boot image"
    set_progress 0.5
    BACKUP_FILE="/sdcard/boot_backup_$(date +%H%M%S).img"
    if dd if="$BOOT_PARTITION" of="$BACKUP_FILE" bs=4096 2>/dev/null; then
        log_info "Backup saved to: $BACKUP_FILE"
    else
        dd if="$BOOT_PARTITION" of="$TMPDIR/boot.img" bs=4096
        log_info "Backup saved to temp directory"
    fi
    
    log_step "Unpacking boot image"
    set_progress 0.6
    magiskboot unpack "$TMPDIR/boot.img" 2>/dev/null || \
    magiskboot unpack "$BACKUP_FILE" 2>/dev/null || {
        log_fail "Failed to unpack boot image"
        exit 1
    }
    
    log_step "Replacing kernel"
    set_progress 0.7
    [ -f "$TMPDIR/Image" ] && cp "$TMPDIR/Image" "$TMPDIR/kernel"
    
    log_step "Repacking boot image"
    set_progress 0.8
    magiskboot repack "$TMPDIR/boot.img" "$TMPDIR/boot_new.img" || {
        log_fail "Failed to repack boot image"
        exit 1
    }
    
    log_step "Flashing to $BOOT_PARTITION"
    set_progress 0.9
    dd if="$TMPDIR/boot_new.img" of="$BOOT_PARTITION" bs=4096 || {
        log_fail "Flash failed"
        exit 1
    }
    
    log_done "Flashing complete"
    set_progress 1.0
    
    # Cleanup
    cd /
    rm -rf "$TMPDIR"
    ui_print " "
    ui_print "****************************************"
    ui_print "*     Kernel Flashed Successfully!     *"
    ui_print "****************************************"
    exit 0
fi

# Fallback: Try to use AIK (Android Image Kitchen) if available
if [ -d "/tmp/AIK" ] || [ -d "/data/local/tmp/AIK" ]; then
    AIK_DIR="/tmp/AIK"
    [ -d "/data/local/tmp/AIK" ] && AIK_DIR="/data/local/tmp/AIK"
    
    ui_print "Using Android Image Kitchen..."
    # AIK method would go here
    ui_print "AIK method not fully implemented"
fi

# Final fallback: Direct flash (risky, device-specific)
log_warn "Using direct flash method (risky, may cause bootloop)"

BOOT_PARTITION=$(find_boot_partition)

if [ -z "$BOOT_PARTITION" ] || [ ! -e "$BOOT_PARTITION" ]; then
    log_fail "Boot partition not found"
    exit 1
fi

log_step "Directly flashing kernel to $BOOT_PARTITION"
dd if="$TMPDIR/Image" of="$BOOT_PARTITION" bs=4096 seek=2048 conv=notrunc || {
    log_fail "Direct flash failed"
    exit 1
}

log_done "Kernel flashed (direct method)"
ui_print "Reflash current kernel if device fails to boot!"

rm -rf "$TMPDIR"
EOF

    chmod +x "$ANYKERNEL_DIR/META-INF/com/google/android/update-binary"
    
    # Copy kernel image到anykernel目录
    cp "$IMAGE_PATH" "$ANYKERNEL_DIR/Image"

    # 生成符合 AK3 标准的 anykernel.sh (作为描述文件和备用脚本)
    ANYKERNEL_BUILD_DATE=$(date +%Y-%m-%d)
    cat > "$ANYKERNEL_DIR/anykernel.sh" <<ANYKERNEL_EOF
# AnyKernel3 Properties
do.devicecheck=1
do.modules=0
do.cleanup=1
do.cleanuponabort=0
device.name1=fuxi
device.name2=xiaomi13
supported.versions=13, 14
supported.patchlevels=

# Built by Serein Build System
build.date=$ANYKERNEL_BUILD_DATE
kernel.string=Serein GKI Kernel for Xiaomi 13

# Simple logic for shells that source anykernel.sh
if [ "\$1" != "setup" ]; then
    ui_print " "
    ui_print "Running backup anykernel.sh logic..."
    # ... (简化的逻辑可放在这)
fi
ANYKERNEL_EOF

    chmod +x "$ANYKERNEL_DIR/anykernel.sh"

    # 创建 anykernel.zip
    cd "$ANYKERNEL_DIR"
    zip -r "$OUT_DIR/anykernel.zip" . > /dev/null
    cd "$KERNEL_ROOT"
    rm -rf "$ANYKERNEL_DIR"

    log "✓ anykernel.zip created: $OUT_DIR/anykernel.zip"
}


