#!/bin/sh
# yes this was fully vibecoded

set -e

fail() {
    printf "\n Error: %s\n" "$1"
    printf "Exiting...\n"
    exit 1
}

info() {
    printf "\n  %s\n" "$1"
}

success() {
    printf "\n %s\n" "$1"
}

step_header() {
    printf "\n%s\n" "$1"
    printf "%s\n" "$(printf '%0.s─' $(seq 1 40))"
}

# Step 1: Introduction
clear
step_header "ChromeOS Partition Management Walkthrough"
echo "This script will guide you through managing ChromeOS partitions."
echo "This process will:"
echo "  1. Identify your current boot partition"
echo "  2. Delete the non-booted ChromeOS partition"
echo "  3. Wipe the stateful partition"
echo ""
echo "WARNING: This will delete data! Make sure you have backups!"
echo ""

read -p "Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
fi

# Step 2: List block devices
step_header "Step 2: Identifying Block Devices"
echo "Listing available block devices..."
echo ""
fdisk -l 2>/dev/null || lsblk
echo ""
echo "Look for devices with many partitions (12-14)."
echo "Common internal devices: mmcblk0, mmcblk1, nvme0n1"
echo ""
read -p "Enter the internal device path (e.g., /dev/mmcblk0): " internal_dev

if [ ! -b "$internal_dev" ]; then
    fail "Device $internal_dev not found or not a block device"
fi

# Step 3: Check kernel priorities
step_header "Step 3: Checking Kernel Priorities"
info "Checking GPT priorities for kernels A and B..."

priority_2=$(cgpt show -n "$internal_dev" -i 2 -P 2>/dev/null || echo "0")
priority_4=$(cgpt show -n "$internal_dev" -i 4 -P 2>/dev/null || echo "0")

echo "Kernel A (partition 2) priority: $priority_2"
echo "Kernel B (partition 4) priority: $priority_4"

if [ "$priority_2" -eq 0 ] && [ "$priority_4" -eq 0 ]; then
    fail "Could not read GPT priorities. Is this a ChromeOS device?"
fi

# Determine which kernel is booted
if [ "$priority_2" -gt "$priority_4" ]; then
    booted_kern=2
    booted_root=3
    delete_kern=4
    delete_root=5
    info "Currently booted from Kernel A (partition 2)"
else
    booted_kern=4
    booted_root=5
    delete_kern=2
    delete_root=3
    info "Currently booted from Kernel B (partition 4)"
fi

echo ""
echo "Will DELETE:"
echo "  Kernel partition: $delete_kern"
echo "  Root partition: $delete_root"
echo ""
echo "Will KEEP:"
echo "  Kernel partition: $booted_kern"
echo "  Root partition: $booted_root"
echo ""

read -p "Continue with these changes? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
fi

# Step 4: Prepare chroot
step_header "Step 4: Preparing Chroot Environment"
info "Setting up chroot into the booted root partition..."

# Determine partition prefix
if echo "$internal_dev" | grep -q "mmcblk\|nvme"; then
    part_prefix="p"
else
    part_prefix=""
fi

booted_root_part="${internal_dev}${part_prefix}${booted_root}"

echo "Mounting $booted_root_part as read-only..."
mkdir -p /localroot
mount "$booted_root_part" /localroot -o ro || fail "Failed to mount root partition"

echo "Binding system directories..."
mount --bind /dev /localroot/dev
mount --bind /proc /localroot/proc
mount --bind /sys /localroot/sys

info "Entering chroot environment..."
echo ""

# Step 5: Interactive fdisk session
step_header "Step 5: Partition Deletion (Interactive)"
echo "Now running fdisk on $internal_dev"
echo "You will delete partitions $delete_kern and $delete_root"
echo ""
echo "Commands to enter in fdisk:"
echo "  d         - delete partition"
echo "  $delete_kern - select kernel partition"
echo "  d         - delete partition"
echo "  $delete_root - select root partition"
echo "  p         - preview changes (optional)"
echo "  w         - write changes"
echo "  q         - quit"
echo ""
echo "DOUBLE CHECK the partition numbers before writing!"
echo ""

read -p "Press Enter to start fdisk, or Ctrl+C to abort..."
echo ""

# Start interactive fdisk
chroot /localroot fdisk "$internal_dev"

# Verify changes were made
echo ""
info "Checking partition table after changes..."
chroot /localroot fdisk -l "$internal_dev" | grep -A 20 "^Device"

# Step 6: Wipe stateful partition
step_header "Step 6: Wiping Stateful Partition"
echo "Options for stateful partition:"
echo "  1. Quick wipe (delete files only)"
echo "  2. Full wipe (reformat partition)"
echo "  3. Skip (don't wipe stateful)"
echo ""
read -p "Select option (1-3): " wipe_option

case $wipe_option in
    1)
        info "Attempting quick wipe..."
        if mount "${internal_dev}${part_prefix}1" /mnt 2>/dev/null; then
            rm -rf /mnt/*
            umount /mnt
            success "Files deleted from stateful partition"
        else
            info "Could not mount partition 1, trying LVM..."
            vgchange -ay 2>/dev/null
            volgroup=$(vgscan 2>/dev/null | grep "Found volume group" | awk '{print $4}' | tr -d '"')
            if [ -n "$volgroup" ]; then
                mount "/dev/$volgroup/unencrypted" /mnt 2>/dev/null
                if [ $? -eq 0 ]; then
                    rm -rf /mnt/*
                    umount /mnt
                    success "Files deleted from LVM stateful partition"
                else
                    echo "Could not mount stateful partition for quick wipe"
                fi
            fi
        fi
        ;;
    2)
        info "Attempting full reformat..."
        echo "This will completely erase the stateful partition!"
        read -p "Are you sure? (type 'YES' to confirm): " confirm
        if [ "$confirm" = "YES" ]; then
            if mount "${internal_dev}${part_prefix}1" /mnt 2>/dev/null; then
                umount /mnt
                chroot /localroot mkfs.ext4 -F "${internal_dev}${part_prefix}1"
                success "Stateful partition reformatted"
            else
                info "Could not mount partition 1, trying LVM..."
                vgchange -ay 2>/dev/null
                volgroup=$(vgscan 2>/dev/null | grep "Found volume group" | awk '{print $4}' | tr -d '"')
                if [ -n "$volgroup" ]; then
                    chroot /localroot mkfs.ext4 -F "/dev/$volgroup/unencrypted"
                    success "LVM stateful partition reformatted"
                else
                    echo "Could not identify stateful partition for reformat"
                fi
            fi
        else
            echo "Skipping reformat."
        fi
        ;;
    3)
        info "Skipping stateful wipe"
        ;;
    *)
        echo "Invalid option, skipping stateful wipe"
        ;;
esac

# Cleanup
step_header "Cleanup"
info "Cleaning up chroot environment..."
umount /localroot/sys 2>/dev/null
umount /localroot/proc 2>/dev/null
umount /localroot/dev 2>/dev/null
umount /localroot 2>/dev/null
rmdir /localroot 2>/dev/null

# Final steps
step_header "Complete!"
echo "Process completed!"
echo ""
echo "Summary of changes:"
echo "  • Deleted partitions: $delete_kern (kernel), $delete_root (root)"
echo "  • Stateful partition: $(case $wipe_option in 1) echo "Quick wiped";; 2) echo "Reformatted";; *) echo "Not modified";; esac)"
echo "  • Boot partition remains: $booted_kern"
echo ""
echo "Important: You need to reboot for changes to take effect."
echo ""
echo "Options:"
echo "  1. reboot -f      - Force reboot immediately"
echo "  2. exit           - Exit without rebooting"
echo ""
read -p "Select option (1 or 2): " reboot_choice

if [ "$reboot_choice" = "1" ]; then
    echo "Rebooting now..."
    reboot -f
else
    echo "You can reboot later with: reboot -f"
    echo "Exiting..."
fi
