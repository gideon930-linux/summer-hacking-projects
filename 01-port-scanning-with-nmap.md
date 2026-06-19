# Project 01 – Port Scanning with Nmap

## Objective

Discover live hosts on my homelab subnet and identify open ports and services on key targets using Nmap.

## Lab Environment

- Attacker: Kali Linux (192.168.3.149)
- Targets:
  - OPNsense – 192.168.3.1
  - Juice Shop / lab host – 192.168.3.53
  - Ubuntu Server – 192.168.3.60
  - Windows 11 – 192.168.3.174
- Network: 192.168.3.0/24

## Step 1 – Host Discovery

Command:

```bash
nmap -sn 192.168.3.0/24 -oN nmap-host-discovery.txt
```

Results:

- 192.168.3.1 – OPNsense
- 192.168.3.53 – lab host
- 192.168.3.149 – Kali
- 192.168.3.174 – Windows 11
- 192.168.3.189 – additional live host discovered

## Step 2 – Service Scan of Windows 11

Command:

```bash
nmap -sV 192.168.3.174 -oN nmap-windows-service-scan.txt
```

Results:

- Host is up
- All 1000 scanned TCP ports were filtered
- No-response filtering suggests firewall protection or blocked access

## Step 3 – Service Scan of Ubuntu Server

Command:

```bash
nmap -sV 192.168.3.60 -oN nmap-ubuntu-service-scan.txt
```

Results:

- 22/tcp open – SSH
- Service detected: OpenSSH 10.2p1 Ubuntu 2ubuntu3.2
- This host appears locked down with only SSH exposed

## Step 4 – Service Scan of Lab Host

Command:

```bash
nmap -sV 192.168.3.53 -oN nmap-proxmox-service-scan.txt
```

Results:

- 22/tcp open – SSH
- 3000/tcp open – HTTP service
- 8081/tcp open – Apache httpd 2.4.25
- 8082/tcp open – Apache Tomcat
- 9090/tcp open – Apache Tomcat

## Common Nmap Options I Used

- `-sn` – Host discovery only (“ping scan”).  
  Nmap only checks which hosts are up, without scanning any ports. Good for safe initial mapping of a subnet.

- `-sV` – Service and version detection.  
  After it finds open ports, Nmap sends extra probes to identify the service and version.

- `-p` – Specify which ports to scan.  
  Examples:  
  - `-p 22` → scan only port 22  
  - `-p 80,443` → scan ports 80 and 443  
  - `-p 1-1024` → scan ports 1 through 1024

- `-p-` – Scan all 65,535 TCP ports.  
  Slower, but helps identify services on uncommon ports.

- `-v` – Verbose output.  
  Shows more detail while the scan is running.

- `-oN <file>` – Save output to a normal text file.  
  Example: `-oN nmap-ubuntu-service-scan.txt`

## Example Commands

- Ping sweep of a subnet:  
  `nmap -sn 192.168.3.0/24 -oN nmap-host-discovery.txt`

- Service scan on a single host:  
  `nmap -sV 192.168.3.60 -oN nmap-ubuntu-service-scan.txt`

- Full port scan with service detection:  
  `nmap -sV -p- 192.168.3.53 -oN nmap-juice-shop-full-scan.txt`

## Lessons Learned

- Host discovery is a good first step before deeper scans.
- A host can be online while still filtering all common ports.
- Service/version detection gives much better context than a basic scan alone.
- The Ubuntu server had minimal exposure, while the lab host exposed several web-related services.

## Files Created

- `nmap-host-discovery.txt`
- `nmap-windows-service-scan.txt`
- `nmap-ubuntu-service-scan.txt`
- `nmap-proxmox-service-scan.txt`
- `nmap-two-hosts.txt`
