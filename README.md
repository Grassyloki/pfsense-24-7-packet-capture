# pfSense 24/7 Packet Capture Script

A lightweight script for running 24/7 packet captures on pfSense with automatic file rotation and cleanup.

## What It Does

- Captures network packets continuously on a specified interface
- Automatically rotates capture files every hour
- Keeps only the last 24 files per interface (24 hours by default)
- Captures only packet headers (not full payloads) to save disk space
- Acts as a watchdog - won't start duplicate captures if already running
- Supports multiple interfaces simultaneously with independent cleanup

## Installation

1. **Create the script:**
```bash
cat > /usr/local/bin/pcap_monitor.sh << 'EOF'
[paste script contents here]
EOF
chmod +x /usr/local/bin/pcap_monitor.sh
```

2. **Test it manually:**
```bash
/usr/local/bin/pcap_monitor.sh cc3
```

3. **Add to cron (pfSense GUI: Services > Cron):**
   - **Schedule:** `*/5 * * * *` (every 5 minutes)
   - **Command:** `/usr/local/bin/pcap_monitor.sh cc3`

## Usage
```bash
./pcap_monitor.sh <interface> [output_directory] [snaplen] [keep_files]
```

### Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **interface** | Yes | - | Network interface to capture (e.g., `cc3`, `em0`, `igb0`) |
| **output_directory** | No | `/root/pcaps/` | Where to store pcap files |
| **snaplen** | No | `96` | Bytes to capture per packet (header only) |
| **keep_files** | No | `24` | Number of files to retain before deleting old ones |

### Examples

**Basic usage (capture on cc3 interface):**
```bash
./pcap_monitor.sh cc3
```

**Custom output directory:**
```bash
./pcap_monitor.sh cc3 /var/log/pcaps
```

**Capture more data per packet (256 bytes) and keep 48 files:**
```bash
./pcap_monitor.sh cc3 /root/pcaps/ 256 48
```

**Multiple interfaces (separate cron entries):**
```bash
# In cron, add multiple entries:
*/5 * * * * /usr/local/bin/pcap_monitor.sh cc3 >/dev/null 2>&1
*/5 * * * * /usr/local/bin/pcap_monitor.sh em0 >/dev/null 2>&1
```

## How It Works

### tcpdump Flags Explained

The script runs tcpdump with these flags:
```bash
/usr/sbin/tcpdump -ni cc3 -U -s 96 -w /root/pcaps/cc3--2025-10-18--14-30-22.pcap -G 3600
```

| Flag | What It Does |
|------|--------------|
| `-n` | Don't resolve hostnames (faster, less load) |
| `-i cc3` | Capture on interface `cc3` |
| `-U` | Write packets immediately (unbuffered) - prevents data loss on crashes |
| `-s 96` | Capture only first 96 bytes of each packet (snaplen) |
| `-w filename.pcap` | Write output to file |
| `-G 3600` | Rotate to new file every 3600 seconds (1 hour) |

### Snaplen (Snapshot Length) Guide

The `-s` flag controls how much of each packet is captured:

| Snaplen | What You Get | Use Case |
|---------|--------------|----------|
| `68` | Ethernet + IP + TCP/UDP headers only | Minimal metadata, smallest files |
| `96` | **Default** - Headers + TCP options, VLAN tags | Good balance for connection tracking |
| `128` | Headers + some application data | Protocol identification |
| `256` | Can see DNS queries, HTTP methods | Basic traffic analysis |
| `0` | Full packets (entire payload) | Complete packet inspection (large files!) |

**Why headers only?** Capturing only headers (`-s 96`) reduces file size by 10-20x while still showing:
- Source/destination IPs and ports
- Protocol types (TCP/UDP/ICMP)
- Packet timestamps
- TCP flags (SYN, ACK, FIN)
- Packet sizes

You DON'T get application data like file downloads, which prevents storage from filling up quickly.

### File Rotation Process

1. **Hour 0:** tcpdump creates `cc3--2025-10-18--12-00-00.pcap`
2. **Hour 1:** tcpdump automatically creates `cc3--2025-10-18--13-00-00.pcap`
3. **Hour 2:** tcpdump creates `cc3--2025-10-18--14-00-00.pcap`
4. **Continues for 24 hours...**
5. **Hour 25:** New file created, oldest file (Hour 0) is deleted by cleanup

### Cron Job Behavior

Every 5 minutes, the cron job:

1. **Checks if tcpdump is running on the specified interface**
   - If NO → Starts new capture
   - If YES → Does nothing (prevents duplicates)

2. **Cleans up old files for that interface**
   - Finds all files matching `interface--*.pcap` pattern
   - Keeps the most recent 24 (or your specified number)
   - Deletes anything older
   - **Note:** Only cleans up files for the specified interface

3. **Reports disk usage**
   - Shows how much space all captures are using

## File Outputs

**Naming format:** `interface--yyyy-mm-dd--hh-mm-ss.pcap`

**Example files for interface cc3:**
```
/root/pcaps/cc3--2025-10-18--12-00-00.pcap  (12:00 PM)
/root/pcaps/cc3--2025-10-18--13-00-00.pcap  (1:00 PM)
/root/pcaps/cc3--2025-10-18--14-00-00.pcap  (2:00 PM)
```

**Example files for interface em0:**
```
/root/pcaps/em0--2025-10-18--12-00-00.pcap  (12:00 PM)
/root/pcaps/em0--2025-10-18--13-00-00.pcap  (1:00 PM)
/root/pcaps/em0--2025-10-18--14-00-00.pcap  (2:00 PM)
```

**Opening files:** All `.pcap` files can be opened directly in Wireshark.

## Multi-Interface Support

The script supports capturing from multiple interfaces simultaneously. Each interface maintains its own set of files and cleanup happens independently.

**Setup multiple interfaces in cron:**
```
*/5 * * * * /usr/local/bin/pcap_monitor.sh cc3 /root/pcaps >/dev/null 2>&1
*/5 * * * * /usr/local/bin/pcap_monitor.sh em0 /root/pcaps >/dev/null 2>&1
*/5 * * * * /usr/local/bin/pcap_monitor.sh igb0 /root/pcaps >/dev/null 2>&1
```

All files will be stored in the same directory but organized by interface name prefix:
```
/root/pcaps/
├── cc3--2025-10-18--12-00-00.pcap
├── cc3--2025-10-18--13-00-00.pcap
├── em0--2025-10-18--12-00-00.pcap
├── em0--2025-10-18--13-00-00.pcap
├── igb0--2025-10-18--12-00-00.pcap
└── igb0--2025-10-18--13-00-00.pcap
```

## Management Commands

**Check if capture is running:**
```bash
ps aux | grep tcpdump
```

**View current captures:**
```bash
ls -lh /root/pcaps/
```

**View captures for specific interface:**
```bash
ls -lh /root/pcaps/cc3--*.pcap
```

**Check disk usage:**
```bash
du -sh /root/pcaps/
```

**Stop all captures:**
```bash
killall tcpdump
```

**Stop capture for specific interface:**
```bash
pkill -f "tcpdump -ni cc3"
```

**Manually run cleanup:**
```bash
/usr/local/bin/pcap_monitor.sh cc3
```

## Storage Estimates

With default settings (`-s 96` snaplen):

| Network Traffic | Storage per Hour | Storage per Day (24 files) |
|-----------------|------------------|-----------------|
| Low (home network) | 10-50 MB | 240 MB - 1.2 GB |
| Medium (small office) | 50-200 MB | 1.2 GB - 4.8 GB |
| High (busy network) | 200-500 MB | 4.8 GB - 12 GB |

**Note:** Full packet capture (`-s 0`) can be 10-20x larger!

**Multiple interfaces:** Multiply the above by the number of interfaces you're capturing.

## Troubleshooting

**Script won't start:**
- Check if interface name is correct: `ifconfig`
- Verify directory permissions: `ls -ld /root/pcaps/`
- Check for typos in interface name

**Files not rotating:**
- Check if tcpdump is actually running: `ps aux | grep tcpdump`
- Verify cron is running: `service cron status`
- Check cron logs: `/var/log/cron`

**Disk filling up:**
- Reduce `keep_files` parameter (e.g., keep only 12 files = 12 hours)
- Reduce `snaplen` to 68 bytes for minimal headers
- Move to larger storage location
- Reduce number of interfaces being captured

**Wrong interface name:**
- List all interfaces: `ifconfig` or `ifconfig -a`
- Common pfSense interface names: `em0`, `em1`, `igb0`, `igb1`, `ix0`, etc.

**Permission denied errors:**
- Ensure script is executable: `chmod +x /usr/local/bin/pcap_monitor.sh`
- Ensure output directory is writable: `chmod 755 /root/pcaps/`

## Security Notes

- Packet captures contain network traffic metadata
- Store captures securely with appropriate permissions
- Be aware of data retention policies in your organization
- Consider encrypting the storage volume if handling sensitive networks
- Limit access to capture files (they contain source/destination IPs and traffic patterns)

## Advanced Usage

**Capture with BPF filter (only SSH traffic):**
```bash
# Modify the tcpdump line in the script to add a filter:
/usr/sbin/tcpdump -ni "$INTERFACE" -U -s "$SNAPLEN" \
    -w "$OUTPUT_DIR/${INTERFACE}--${TIMESTAMP}.pcap" \
    -G 3600 \
    'port 22'
```

**Different retention per interface:**
```bash
# Keep 48 hours of cc3 traffic:
*/5 * * * * /usr/local/bin/pcap_monitor.sh cc3 /root/pcaps 96 48

# Keep only 12 hours of em0 traffic:
*/5 * * * * /usr/local/bin/pcap_monitor.sh em0 /root/pcaps 96 12
```

**Separate directories per interface:**
```bash
*/5 * * * * /usr/local/bin/pcap_monitor.sh cc3 /root/pcaps/wan
*/5 * * * * /usr/local/bin/pcap_monitor.sh em0 /root/pcaps/lan
```
