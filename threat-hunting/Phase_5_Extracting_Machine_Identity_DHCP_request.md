======================================================================
INCIDENT REPORT SUMMARY: PHASE A (Easy as 123)
======================================================================

1. EXECUTIVE SUMMARY
--------------------
On February 28, 2026, network monitoring tools flagged an active 
compromise involving an internal endpoint communicating with a 
malicious external Command and Control (C2) server. Traffic analysis 
confirmed the presence of a NetSupport Manager Remote Access Trojan 
(RAT). The malware has established persistence on the victim host 
and is actively beaconing outbound.

2. ASSET & IDENTITY CORRELATION
-------------------------------
* Victim Hostname:           DESKTOP-TEYQ2NR (via DHCP Request)
* Internal IP Address:       10.2.28.88      (via DHCP / IP Header)
* MAC Address:               00:15:5d:02:28:03 [Microsoft Corp.]
* Compromised User Profile:  brolf [Brian Rolf] (via Kerberos AS-REQ)

3. TECHNICAL TRAFFIC ANALYSIS
-----------------------------
* Malicious C2 Endpoint: 45.131.214.85
* Application Protocol:  Unencrypted HTTP
* Target Port:           443

[SECURITY NOTE] 
Wireshark flagged an Expert Info Warning: "Unencrypted HTTP protocol 
detected over encrypted port". The malware is intentionally tunneling 
plain HTTP traffic through Port 443 to bypass firewall filtering rules 
that assume all Port 443 traffic is secure TLS/HTTPS.

4. C2 MECHANICS & BEACONING
---------------------------
* The initial check-in uses a distinct User-Agent: NetSupport Manager/1.3
  with a POST body parameter of CMD=POLL.
* The server replies with a signature header (Server: NetSupport Gateway/1.92)
  and delivers obfuscated commands via the DATA= parameter.
* Persistence Loop: Following initialization, the malware enters an 
  automated heartbeat loop, executing a POST request containing a 
  36-byte payload (DATA=..#..mH..UAA..g.) exactly every 60 seconds 
  to maintain interactive persistence with the operator.

======================================================================
END OF REPORT
======================================================================
