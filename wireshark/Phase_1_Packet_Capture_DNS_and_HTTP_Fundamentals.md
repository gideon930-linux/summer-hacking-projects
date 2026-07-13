Markdown

# Analyzing HTTP Traffic with Wireshark

## Introduction

In this project, I utilized Wireshark to capture and analyze unencrypted HTTP traffic. Traffic analysis is crucial for understanding web communication, identifying potential security issues, and investigating anomalies in network traffic. By isolating baseline network-layer routines (ICMP), address resolution (DNS), and cleartext application-layer data (HTTP), this lab maps out the complete lifecycle of a web request.

## Pre-requisites

- Deep understanding of basic networking concepts (TCP/IP, ICMP, DNS)
- Kali Linux environment with Wireshark installed
- Web browser (Firefox) for generating target traffic

## Lab Set-up and Tools

1. **Wireshark**: Integrated packet analyzer on Kali Linux (`eth0` interface utilized).
2. **Ping**: Command-line utility used to force immediate network layer communication.
3. **Target Site**: `http://neverssl.com` (chosen explicitly because it does not enforce TLS encryption, allowing cleartext analysis).

---

## Exercises

### Exercise 1: Traffic Generation & Capture Methodology

To analyze the complete baseline of a web request, the capture lifecycle was broken down into two distinct phases to isolate foundational network-layer protocols from application-layer data.

#### Phase A: ICMP Baseline (The Ping Test)
1. Initialized the Wireshark capture on interface `eth0`.
2. Executed the terminal command: `ping neverssl.com`.
3. **Observation:** Isorhythmic ICMP **Echo (ping) request** and **Echo (ping) reply** packets immediately mapped the network path, verifying connection and resolving the target destination IP.
   - **Local Source IP (My Machine):** `192.168.3.149`
   - **Target Destination IP (NeverSSL Server):** `34.223.124.45`

#### Phase B: Connection Handshake and Application Request (DNS & HTTP)
1. Cleared the capture buffer and restarted live capture on `eth0`.
2. Navigated to `http://neverssl.com` via the browser to trigger cleartext application traffic.
3. Terminated the capture immediately post-load to minimize background noise.

---

### Exercise 2: Traffic Isolation and Filter Logic

To efficiently parse the raw capture data, specific Wireshark display filters were leveraged to map the packet flow sequence:

* **DNS Isolation (`dns`):** Applied to isolate the Domain Name System translation. Investigating the `Standard query A neverssl.com` and its corresponding `Standard query response` verified how the local machine mapped the host string to the target IP address.
* **Web Traffic Isolation (`http || tcp.port == 80`):** Applied to view the structural setup and payload delivery of the web session. This exposed:
    1. **The TCP 3-Way Handshake:** Visually verified via sequential `[SYN]`, `[SYN, ACK]`, and `[ACK]` flags passing between `192.168.3.149` and `34.223.124.45` (Packets 2574–2576).
    2. **The HTTP GET Request:** Identified the application-layer request (`GET / HTTP/1.1`) originating from the browser client.
    3. **The HTTP Response:** Identified the server’s acknowledgment and data delivery payload (`HTTP/1.1 200 OK`).

---

### Exercise 3: Analyze HTTP Requests

#### Steps
1. Located and selected the outbound application packet: **Packet #545** (`GET / HTTP/1.1`).
2. Inspected the Application Layer headers inside the packet analysis pane.

#### Key Findings & Headers Captured
* **Host Header:** `grandastoundingmajesticstars.neverssl.com` *(Note: NeverSSL uses randomized subdomains to intentionally bypass local browser caching mechanisms).*
* **User-Agent:** `Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0`
* **Connection Profile:** `keep-alive`

---

### Exercise 4: Analyze HTTP Responses

#### Steps
1. Located the corresponding downstream HTTP server response: **Packet #549** (`HTTP/1.1 200 OK`).
2. Analyzed the status definitions returned by the remote server.

#### Key Findings & Headers Captured
* **Status Code:** `200 OK` (Indicates the request was fulfilled successfully).
* **Server Infrastructure:** `Apache/2.4.66 ()`
* **Content-Type:** `text/html; charset=UTF-8`
* **Content-Encoding:** `gzip` (The payload data was compressed for transit).

---

### Exercise 5: Extract and Examine Payload Data

#### Steps
1. Right-clicked on the primary HTTP sequence and selected **Follow** > **TCP Stream**.
2. Analyzed the full stream (`tcp.stream eq 13`) to observe the application-layer transaction tracking both Client data (red text) and Server data (blue text).

#### Extracted Data Stream Payload
Because the site omitted SSL/TLS, the raw headers and application formatting were laid out in human-readable plain text:

```http
GET / HTTP/1.1
Host: grandastoundingmajesticstars.neverssl.com
User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0
Accept: */*

HTTP/1.1 200 OK
Date: Tue, 30 Jun 2026 22:34:21 GMT
Server: Apache/2.4.66 ()
Content-Length: 1900
Content-Type: text/html; charset=UTF-8

[Compressed raw website binary structure/HTML payload displayed below headers]

### Conclusion

By completing this lab, I successfully demonstrated the complete lifecycle of unencrypted web transactions: resolving endpoints via DNS/Ping, monitoring the physical TCP 3-Way Handshake (SYN ➡️ SYN-ACK ➡️ ACK), parsing explicit request methods, and fully reconstructing plain text payloads from application bytes. These skills are essential for fundamental network troubleshooting, security baseline auditing, and performing digital forensics
