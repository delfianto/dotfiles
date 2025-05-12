#!/bin/zsh

# Check active xdg-desktop-portal service
echo "Checking xdg-desktop-portal status..."
systemctl --user status xdg-desktop-portal.service --quiet && echo "xdg-desktop-portal is running" || echo "xdg-desktop-portal not running"

# Check active portal backends
echo "Checking active portal backends..."
active_backend=$(cat ~/.config/xdg-desktop-portal/portals.conf | grep -i "default" | awk -F'=' '{print $2}')
echo "Active portal backend: ${active_backend:-Not set}"

# Check installed packages for xdg-desktop-portal and backends
echo "Checking installed packages related to xdg-desktop-portal..."
pacman -Qs 'xdg-desktop-portal'

# Check for installed thumbnailers
echo "Checking for installed thumbnailers..."
pacman -Qs 'thumbnailer'

# Check if tumblerd is running for thumbnail generation
echo "Checking tumblerd status..."
ps aux | grep tumblerd || echo "tumblerd is not running"

# Check for any KDE portal-related packages (not recommended unless KDE environment)
echo "Checking for any KDE-related portal packages..."
pacman -Qs 'xdg-desktop-portal-kde'

echo "Portal diagnostic complete!"
