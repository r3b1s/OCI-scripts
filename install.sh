#!/bin/bash

set -e

echo "======================================"
echo "OCI Load Balancer"
echo "======================================"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root (use sudo)"
   exit 1
fi

# Check if running on Arch Linux
if ! grep -qi "arch" /etc/os-release; then
    echo "Warning: This script is designed for Arch Linux"
    echo "Some commands may not work on other distributions"
fi

packages = (
  "bc"
  "python3"
  "sysstat"
)
sudo pacman -Syy
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm ${packages[@]}

# Variables
INSTALL_DIR="/opt/load-balancer"
SCRIPT_NAME="load_balancer.sh"
SERVICE_NAME="load-balancer.service"
SERVICE_USER="loady"

# Check if $SERVICE_USER exists, create if not
if ! id "$SERVICE_USER" &>/dev/null; then
    echo "Creating user '$SERVICE_USER'..."
    useradd -r -s /bin/bash "$SERVICE_USER" || {
        echo "Failed to create user '$SERVICE_USER'"
        exit 1
    }
    echo "User '$SERVICE_USER' created successfully"
else
    echo "User '$SERVICE_USER' already exists"
fi

# Create installation directory
echo "Creating installation directory at $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"

# Copy load_balancer.sh script
if [[ ! -f "$SCRIPT_NAME" ]]; then
    echo "Error: $SCRIPT_NAME not found in current directory"
    exit 1
fi
echo "Installing $SCRIPT_NAME to $INSTALL_DIR..."
cp "$SCRIPT_NAME" "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/$SCRIPT_NAME"

# Copy load_generator.py script
if [[ ! -f "load_generator.py" ]]; then
    echo "Error: load_generator.py not found in current directory"
    exit 1
fi
echo "Installing load_generator.py to $INSTALL_DIR..."
cp load_generator.py "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/load_generator.py"
chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR/load_generator.py"

# Create and install systemd service file
echo "Creating systemd service file..."
cat > /etc/systemd/system/$SERVICE_NAME << SERVICEEOF
[Unit]
Description=Automatic CPU Load Balancer
After=network.target

[Service]
Type=simple
User=$SERVICE_USER
WorkingDirectory=$INSTALL_DIR
ExecStart=/bin/bash $INSTALL_DIR/$SCRIPT_NAME
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

chmod 644 /etc/systemd/system/$SERVICE_NAME
echo "Service file created at /etc/systemd/system/$SERVICE_NAME"

# Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload

# Enable the service for autostart
echo "Enabling $SERVICE_NAME for autostart..."
systemctl enable --now $SERVICE_NAME

echo ""
echo "======================================"
echo "Installation Complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Check status:"
echo "   sudo systemctl status $SERVICE_NAME"
echo ""
echo "2. View logs:"
echo "   sudo journalctl -u $SERVICE_NAME -f"
echo ""
echo "Installation details:"
echo "  - Script location: $INSTALL_DIR/$SCRIPT_NAME"
echo "  - Service user: $SERVICE_USER"
echo "  - Service name: $SERVICE_NAME"
echo "======================================"
