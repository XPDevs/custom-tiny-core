#!/bin/bash

INTERFACE="wlan0"

# Function to scan wifi networks and return SSIDs
scan_wifi() {
    sudo iwlist $INTERFACE scan | grep 'ESSID:' | sed 's/.*ESSID:"\(.*\)"/\1/' | grep -v '^$' | sort -u
}

# Function to connect to a network with wpa_supplicant
connect_wifi() {
    local ssid="$1"
    local password="$2"

    # Create a temporary wpa_supplicant config file
    TMP_CONF=$(mktemp)
    cat > "$TMP_CONF" << EOF
network={
    ssid="$ssid"
    psk="$password"
}
EOF

    sudo killall wpa_supplicant 2>/dev/null
    sudo ip link set $INTERFACE down
    sudo wpa_supplicant -B -i $INTERFACE -c "$TMP_CONF"
    sudo dhclient $INTERFACE

    rm -f "$TMP_CONF"
}

# Start script

# Step 1: Scan Wi-Fi and get SSIDs
SSID_LIST=$(scan_wifi)

if [ -z "$SSID_LIST" ]; then
    zenity --error --text="No Wi-Fi networks found. Please make sure your interface is up."
    exit 1
fi

# Step 2: Show list to user via zenity
SSID_SELECTED=$(echo "$SSID_LIST" | zenity --list --title="Select Wi-Fi Network" --column="SSID" --height=300 --width=300)

if [ -z "$SSID_SELECTED" ]; then
    zenity --info --text="No network selected. Exiting."
    exit 0
fi

# Step 3: Ask for password (empty if open network)
PASSWORD=$(zenity --password --title="Password for $SSID_SELECTED" --text="Enter Wi-Fi password (leave empty for open network):")

# Step 4: Connect
if [ -z "$PASSWORD" ]; then
    # Open network - use iwconfig
    sudo ip link set $INTERFACE up
    sudo iwconfig $INTERFACE essid "$SSID_SELECTED"
    sudo dhclient $INTERFACE
else
    connect_wifi "$SSID_SELECTED" "$PASSWORD"
fi

# Step 5: Show success or failure (simple check)
PING_TEST=$(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "Success" || echo "Failure")

if [ "$PING_TEST" = "Success" ]; then
    zenity --info --text="Connected to $SSID_SELECTED successfully!"
else
    zenity --error --text="Failed to connect to $SSID_SELECTED."
fi
