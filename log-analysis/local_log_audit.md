Markdown# Local Log Auditing & System Journal Analysis Report

## Project Overview
This laboratory documentation evaluates local log activity, system authentication flows, and kernel events on a Linux platform[cite: 1, 2]. By analyzing native system components, legacy text logs, and binary `systemd` journals, this project maps how defenders monitor system health, detect application crashes, and identify indicators of compromise (IoCs)[cite: 1].

---

## Part 1: Open Authentication Log Evaluation (`auth.log`)

### Objective
Review system-wide authentication tracking to look for failed login attempts, verify account lifecycle events, and monitor privilege escalation commands.

### Actions Executed
```bash
# Tracking successful elevated commands (sudo executions)
** Bash sudo grep "COMMAND=" /var/log/auth.log

# Watching session handshakes to monitor terminal connections
** Bash grep -E "session opened|session closed" /var/log/auth.log

## Defensive Analysis Checklist:
Defenders use these parameters to separate normal operational noise from suspicious behavior:
- Velocity Anomalies: A low number of spaced-out password failures suggests a human typo; massive volumes of rapid, simultaneous failures indicate signature-based automated cracking tools.  
- Account Harvesting: Identifying persistent connection rejections targeting default or system-level service profiles (e.g., www-data, nobody) that lack legitimate interactive login privileges.
- Temporal Deviations: Auditing standard login timeframes to spot off-hours activity or impossible geographic travel markers.

## Part 2: Native System Journal Deep-Dive (journalctl)
- Objective
Query the local binary systemd journal database to isolate process instabilities, detect hardware-level virtual infrastructure configurations, and profile the loudest logging daemons.

## Phase 1: Process Crashes & Memory Allocation
** Bash sudo journalctl -g "segfault|dumped core|killed|out of memory|oom-killer"

Terminal Output:
Plaintext -- Boot 6bceb6e53ff346b0a483c3bec8d3c2a5 --
Jul 10 18:23:48 kali kernel: systemd-sslh-ge[29110]: segfault at 0 ip 00007ff5379722d1 sp 00007ffdff4d7068>
Jul 10 18:44:27 kali kernel: systemd-sslh-ge[70196]: segfault at 0 ip 00007f5cc33812d1 sp 00007ffe2766ddf8>
Jul 10 18:48:16 kali kernel: systemd-sslh-ge[94866]: segfault at 0 ip 00007f597c5e72d1 sp 00007ffdd65fb628>
Jul 10 18:48:22 kali kernel: systemd-sslh-ge[95373]: segfault at 0 ip 00007ffefcfabc78>
Jul 10 18:48:37 kali kernel: systemd-sslh-ge[97885]: segfault at 0 ip 00007f75270532d1 sp 00007ffd11ea2068>
Jul 10 23:18:52 kali kernel: systemd-sslh-ge[245660]: segfault at 0 ip 00007f5fee3792d1 sp 00007ffe47d413d>
Jul 10 23:49:41 kali sudo[261580]:   gideon : TTY=pts/2 ; PWD=/home/gideon/Downloads ; USER=root ; COMMAND>
Jul 10 23:50:51 kali sudo[262187]:   gideon : TTY=pts/2 ; PWD=/home/gideon/Downloads ; USER=root ; COMMAND>

## Defensive Evaluation:
The system journal caught a clear, high-density error chain involving six distinct segmentation faults (segfault at 0) tracking back to the application daemon systemd-sslh-generator. The memory space error code points to a recurring Null Pointer Dereference flaw occurring during early boot or service initialization. In production, this pattern reveals a corrupted or unstable application configuration that risks a local denial-of-service condition.

## Phase 2: Hardware Footprint & Peripheral Event Verification
** Bash sudo journalctl -k -g "usb|removable|direct-access" | head -n 20

Terminal Output:
Plaintext Jul 10 17:42:31 kali kernel: ACPI: bus type USB registered
Jul 10 17:42:31 kali kernel: usbcore: registered new interface driver usbfs
Jul 10 17:42:31 kali kernel: usbcore: registered new interface driver hub
Jul 10 17:42:31 kali kernel: usbcore: registered new device driver usb
Jul 10 17:42:31 kali kernel: ehci-pci 0000:00:0b.0: new USB bus registered, assigned bus number 1
Jul 10 17:42:31 kali kernel: ehci-pci 0000:00:0b.0: USB 2.0 started, EHCI 1.00
Jul 10 17:42:31 kali kernel: usb usb1: New USB device found, idVendor=1d6b, idProduct=0002, bcdDevice= 6.18
Jul 10 17:42:31 kali kernel: usb usb1: New USB device strings: Mfr=3, Product=2, SerialNumber=1
Jul 10 17:42:31 kali kernel: usb usb1: Product: EHCI Host Controller
Jul 10 17:42:31 kali kernel: usb usb1: Manufacturer: Linux 6.18.12+kali-amd64 ehci_hcd
Jul 10 17:42:31 kali kernel: usb usb1: SerialNumber: 0000:00:0b.0
Jul 10 17:42:31 kali kernel: hub 1-0:1.0: USB hub found
Jul 10 17:42:31 kali kernel: ohci-pci 0000:00:06.0: new USB bus registered, assigned bus number 2
Jul 10 17:42:32 kali kernel: usb usb2: New USB device found, idVendor=1d6b, idProduct=0001, bcdDevice= 6.18
Jul 10 17:42:32 kali kernel: usb usb2: New USB device strings: Mfr=3, Product=2, SerialNumber=1
Jul 10 17:42:32 kali kernel: usb usb2: Product: OHCI PCI host controller
Jul 10 17:42:32 kali kernel: usb usb2: Manufacturer: Linux 6.18.12+kali-amd64 ohci_hcd
Jul 10 17:42:32 kali kernel: usb usb2: SerialNumber: 0000:00:06.0
Jul 10 17:42:32 kali kernel: hub 2-0:1.0: USB hub found
Jul 10 17:42:32 kali kernel: scsi 1:0:0:0: Direct-Access     ATA      VBOX HARDDISK    1.0  PQ: 0 ANSI: 5

## Defensive Evaluation:
This log segment defines the underlying hardware baseline architecture. The identification of standard host controllers alongside the explicit drive mapping string (VBOX HARDDISK) confirms that this kernel is executing inside a hypervisor guest instance managed by Oracle VirtualBox rather than operating on bare-metal physical components.Phase 

## 3: Service Initialization and System Lifecycle States
** Bash sudo journalctl -g "stopping|stopped|started|exited" | grep -v "systemd\[1\]" | head -n 30

Terminal Output:
Plaintext Jul 10 14:32:37 kali kernel: ehci-pci 0000:00:0b.0: USB 2.0 started, EHCI 1.00
Jul 10 14:32:37 kali systemd-journald[323]: Journal started
Jul 10 14:32:39 kali polkitd[543]: Started polkitd version 126
Jul 10 14:32:39 kali virtualbox-guest-utils[586]: 18:32:39.976355 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:32:39 kali kernel: 18:32:39.976355 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:32:39 kali accounts-daemon[541]: started daemon version 23.13.9
Jul 10 14:32:40 kali virtualbox-guest-utils[596]: 18:32:40.032843 main     7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:32:40 kali kernel: 18:32:40.032843 main     7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:32:42 kali systemd[738]: Started pipewire.service - PipeWire Multimedia Service.
Jul 10 14:32:42 kali systemd[738]: Started dbus.service - D-Bus User Message Bus.
Jul 10 14:32:42 kali systemd[738]: Started wireplumber.service - Multimedia Service Session Manager.
Jul 10 14:32:42 kali systemd[738]: Started filter-chain.service - PipeWire filter chain daemon.
Jul 10 14:32:42 kali systemd[738]: Started pipewire-pulse.service - PipeWire PulseAudio.
Jul 10 14:32:42 kali systemd[738]: Started at-spi-dbus-bus.service - Accessibility services bus.
Jul 10 14:32:42 kali systemd[738]: Started gvfs-daemon.service - Virtual filesystem service.
Jul 10 14:32:43 kali systemd[738]: Started gvfs-metadata.service - Virtual filesystem metadata service.
Jul 10 14:34:07 kali systemd[921]: Started pipewire.service - PipeWire Multimedia Service.
Jul 10 14:34:07 kali systemd[921]: Started gnome-keyring-daemon.service - GNOME Keyring daemon.
Jul 10 14:34:07 kali systemd[921]: Started dbus.service - D-Bus User Message Bus.
Jul 10 14:34:07 kali systemd[921]: Started mpris-proxy.service - Bluetooth mpris proxy.
Jul 10 14:34:07 kali systemd[921]: Started wireplumber.service - Multimedia Service Session Manager.
Jul 10 14:34:07 kali systemd[921]: Started filter-chain.service - PipeWire filter chain daemon.
Jul 10 14:34:07 kali systemd[921]: Started pipewire-pulse.service - PipeWire PulseAudio.
Jul 10 14:34:07 kali kernel: 18:34:07.621001 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:34:07 kali kernel: 18:34:07.630576 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:34:07 kali kernel: 18:34:07.641313 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:34:07 kali kernel: 18:34:07.643739 main      Service started
Jul 10 14:34:07 kali kernel: 18:34:07.652522 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:34:07 kali kernel: 18:34:07.660994 main      VBoxClient 7.2.4_Debian r170995 started. Verbose level = 0
Jul 10 14:34:07 kali virtualbox-guest-utils[604]: 18:34:07.671091 IpcCLT-1066 VBoxDRMClient: IPC client connection started

## Defensive Evaluation:
This output maps a clean background orchestration trail during system user-space initialization. The chronology captures the authorization management framework (polkitd), standard desktop messaging layers (dbus), and local hardware sound engines (pipewire) running cleanly without indicative disruption or service manipulation.

## Phase 4: Operational Process Densities (Loudest Daemons)
** Bash sudo journalctl | awk '{print $5}' | sort | uniq -c | sort -nr | head -n 10

## Terminal Output:Plaintext  
   1384 kernel:
   1192 systemd[1]:
    156 dbus-daemon[511]:
    140 dbus-daemon[943]:
    136 polkitd[512]:
    105 systemd-sslh-generator:
    105 systemd[919]:
     93 systemd[921]:
     87 systemd[738]:
     87 systemd[725]:

##Defensive Evaluation:This process parsing step quantifies the volume of telemetry output to identify anomalies or misconfigured packages generating excessive logging noise. While the kernel and primary system initialization manager (systemd[1]) expectedly hold the largest data footprints, systemd-sslh-generator generated an unusually disproportionate footprint of 105 entries. This structural outlier correlates directly back to the process crashes flagged in Phase 1, validating the application's runtime failure loops.

## Part 3: Strategic Mitigations & Remediation Plan
Based on the forensic indicators captured across the system logs and journals, the following defensive remediation procedures are recommended for the local machine:
- Resolve Application Instabilities: Since systemd-sslh-generator is caught in a continuous error loop, evaluate its necessity. If the multiplexer is unneeded, purge the package to eliminate logging overhead and clear potential software risk vectors:
** Bash sudo apt purge sslh -y

- If the application protocol multiplexer is required for operational port management, apply updates to fix structural coding defects:
** Bash sudo apt update && sudo apt install --only-upgrade sslh -y

- Establish Diagnostic Baselines: Use the log volume metrics to construct a standardized telemetry baseline, ensuring automated alerts are configured to flag anomalies whenever non-standard system daemons rapidly increase their log generation densities.

## Part 4: Network Segmentation & Perimeter Firewall Auditing (OPNsense)

### Objective
Demonstrate stateful packet filtering logic by implementing an explicit access control policy between a testing node and an internal server node hosted within a Proxmox virtual environment.

### Environment Architecture
*   **Security Gateway:** OPNsense Virtual Appliance
*   **Attacker/Testing Node (Kali Linux):** `192.168.3.149`
*   **Target Server Node (Ubuntu):** `192.168.3.60`
*   **Target Application Port:** `8080/TCP`

### Phase 1: Baseline Verification (Pre-Rule State)
Prior to rule enforcement, a network listener was established on the target server, and connection availability was verified from the testing endpoint.

```bash
# Executed on Kali Attacker
nc -zv 192.168.3.60 8080

Terminal Output:
Plaintext

192.168.3.60 8080 (http-alt) open

Analysis: The gateway default configuration permitted unrestricted inter-device traffic across the internal interface segment, establishing an unhardened baseline.
Phase 2: Policy Enforcement & Action Verification (Post-Rule State)

An explicit rule was written inside the OPNsense LAN interface rules stack to intercept inbound traffic originating from the testing host targeting the server profile on port 8080:

    Action: Reject / Block

    Protocol: TCP

    Source Address: 192.168.3.149

    Destination Address: 192.168.3.60

    Destination Port: 8080

Following policy application, the connection test was executed a second time:
Bash 

# Executed on Kali Attacker after OPNsense policy commit
nc -zv 192.168.3.60 8080

Terminal Output:
Plaintext

192.168.3.60: inverse host lookup failed: Unknown host
(UNKNOWN) [192.168.3.60] 8080 (http-alt) : No route to host

Defensive Analysis:
The transition from open to No route to host confirms absolute packet interception. Because the policy executed a reject operation, the OPNsense firewall actively generated an ICMP destination unreachable response back to the source IP, instantly terminating the TCP handshake attempt. This proves stateful boundary enforcement at the network layer.


