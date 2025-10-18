#!/bin/bash
#
# Continuous Packet Capture Script for pfSense
#
# USAGE: ./pcap_monitor.sh <interface> [output_directory] [snaplen] [keep_files]
#   interface       - Network interface to capture (e.g., cc3, em0, igb0)
#   output_directory - Optional: Directory to store pcap files (default: /root/pcaps/)
#   snaplen         - Optional: Bytes to capture per packet (default: 96 for headers only)
#   keep_files      - Optional: Number of pcap files to retain (default: 24)
#
# EXAMPLES:
#   ./pcap_monitor.sh cc3
#   ./pcap_monitor.sh cc3 /var/log/pcaps
#   ./pcap_monitor.sh em0 /root/pcaps/ 128 48
#
# OUTPUT FILENAME FORMAT:
#   interface--yyyy-mm-dd--hh-mm-ss.pcap
#   Example: cc3--2025-10-18--14-30-22.pcap
#
# CRON SETUP:
#   Run every 5 minutes to ensure capture is running and cleanup old files:
#   */5 * * * * /usr/local/bin/pcap_monitor.sh cc3 >/dev/null 2>&1
#
# INSTALLATION:
#   1. Save this script to /usr/local/bin/pcap_monitor.sh
#   2. chmod +x /usr/local/bin/pcap_monitor.sh
#   3. mkdir -p /root/pcaps (default directory will be created automatically)
#   4. Add cron entry via pfSense: Services > Cron
#

# Parse input variables
INTERFACE="${1}"
OUTPUT_DIR="${2:-/root/pcaps/}"  # Default to /root/pcaps/
SNAPLEN="${3:-96}"               # Default to 96 bytes (headers only)
KEEP_FILES="${4:-24}"            # Default to keep 24 files

# Validate inputs
if [ -z "$INTERFACE" ]; then
    echo "Error: Missing required interface parameter"
    echo "Usage: $0 <interface> [output_directory] [snaplen] [keep_files]"
    exit 1
fi

# Create output directory if it doesn't exist
if [ ! -d "$OUTPUT_DIR" ]; then
    mkdir -p "$OUTPUT_DIR"
    if [ $? -ne 0 ]; then
        echo "Error: Could not create output directory $OUTPUT_DIR"
        exit 1
    fi
    echo "$(date): Created output directory $OUTPUT_DIR"
fi

# Check if tcpdump is already running on this interface
RUNNING=$(ps aux | grep "[t]cpdump -ni $INTERFACE" | grep -v grep)

if [ -z "$RUNNING" ]; then
    # tcpdump not running, start it
    TIMESTAMP=$(date +%Y-%m-%d--%H-%M-%S)
    nohup /usr/sbin/tcpdump -ni "$INTERFACE" -U -s "$SNAPLEN" \
        -w "$OUTPUT_DIR/${INTERFACE}--${TIMESTAMP}.pcap" \
        -G 3600 \
        >/dev/null 2>&1 &
    
    echo "$(date): Started tcpdump on $INTERFACE (PID: $!)"
else
    echo "$(date): tcpdump already running on $INTERFACE"
fi

# Cleanup old files - keep only the most recent files for this interface
find "$OUTPUT_DIR" -name "${INTERFACE}--*.pcap" -type f | \
    sort -r | \
    tail -n +$((KEEP_FILES + 1)) | \
    xargs rm -f 2>/dev/null

# Report disk usage
USAGE=$(du -sh "$OUTPUT_DIR" 2>/dev/null | cut -f1)
echo "$(date): Disk usage: $USAGE"

exit 0
