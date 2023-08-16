#!/bin/bash

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Set variables
USERNAME="edx"
HOSTNAME="gr0m"  # Updated hostname
TIMEZONE="Europe/London"
LOCALE="en_GB.UTF-8"
KEYMAP="uk"
BOOT_NAME="Redacted Linux"  # Custom boot name
SWAP_SIZE="4G"  # Swap partition size
PACKAGES=("vim" "git" "openssh" "firefox" "plasma-desktop" "neofetch" "linux-lts")  # Additional packages including KDE Plasma, neofetch, and linux-lts

# Update system clock
timedatectl set-ntp true

# Partitioning (Adjust as needed)
# WARNING: This will delete all data on the specified drive. Make sure you've backed up your data.
# In this example, we'll use /dev/sda with a 512MB EFI partition, 4GB swap, and the rest for root and home partitions.
# Change /dev/sda to your target drive.
(
  echo g      # Create a new GPT partition table
  echo n      # New partition
  echo        # Default partition number (1)
  echo        # Default start sector
  echo +512M  # EFI partition size
  echo ef00   # EFI partition type
  echo n      # New partition
  echo        # Default partition number (2)
  echo        # Default start sector
  echo +$SWAP_SIZE  # Swap partition size
  echo 8200   # Swap partition type
  echo n      # New partition
  echo        # Default partition number (3)
  echo        # Default start sector
  echo        # Default end sector (Use all available space)
  echo        # Leave empty for Linux filesystem
  echo w      # Write changes
) | gdisk /dev/sda

# Format partitions
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
mkfs.ext4 /dev/sda3

# Mount partitions
mount /dev/sda3 /mnt
mkdir -p /mnt/boot/efi
mount /dev/sda1 /mnt/boot/efi
swapon /dev/sda2

# Select UK mirrors and update mirrorlist
curl -s "https://archlinux.org/mirrorlist/?country=GB&protocol=https" | sed -e 's/^#Server/Server/' -e '/^#/d' > /etc/pacman.d/mirrorlist

# Install base system
pacstrap /mnt base base-devel linux-lts linux-firmware

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Chroot into the new system
arch-chroot /mnt /bin/bash <<EOF

# Set timezone
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

# Set locale
echo "$LOCALE UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

# Set keymap
echo "KEYMAP=$KEYMAP" > /etc/vconsole.conf

# Set hostname
echo "$HOSTNAME" > /etc/hostname

# Set root password
echo "Set root password:"
passwd

# Install and configure bootloader (GRUB in this example)
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub
echo "GRUB_DISTRIBUTOR=\"$BOOT_NAME\"" >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Create a user
useradd -m -G wheel $USERNAME
echo "$USERNAME password:"
passwd $USERNAME

# Enable sudo for the user
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel

# Install additional packages
pacman -S ${PACKAGES[@]}

# Thank you message
cat <<EOT

**************************************************************
**                                                          **
**           Thank you for using this installation          **
**                script. Your system is now                **
**            being set up. Please wait patiently.          **
**                                                          **
**************************************************************

EOT

EOF

# Unmount partitions, remove swap, and reboot
umount -R /mnt
swapoff /dev/sda2

# Thank you message before reboot
echo "System installation completed. Thank you for choosing us!"
read -p "Press Enter to reboot your system."

reboot
