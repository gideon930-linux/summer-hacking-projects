======================================================================
                     INCIDENT REPORT SUMMARY
======================================================================

1. EXECUTIVE SUMMARY
During a routine network packet inspection, multiple legacy discovery 
and authentication protocols were cross-examined alongside web traffic. 
The internal asset profile was successfully mapped, identifying a 
local host establishing multiple broadcast/multicast queries (NBNS, 
LLMNR, BROWSER). Security auditing of these protocols reveals potential 
exposures to unauthenticated spoofing attacks (e.g., LLMNR/NBNS 
poisoning via tools like Responder). Furthermore, tracking active 
directory and Kerberos communication helped securely correlate network 
traffic back to an authenticated user identity.

----------------------------------------------------------------------
2. VICTIM ASSET & IDENTITY PROFILE
The following details uniquely identify the target system on the 
internal network segment:

* Internal IP Address: 10.1.21.58
* Device Hostname: DESKTOP-ES9F3ML
* Mapped Local Workgroup/Domain: WIN11OFFICE

----------------------------------------------------------------------
3. PROTOCOL & TRAFFIC BREAKDOWN

A. Local Discovery Protocols (NBNS / LLMNR / BROWSER)
* Observation: The victim machine was observed sending multiple 
  multicast queries over LLMNR to 224.0.0.252 and subnet broadcasts 
  over NetBIOS Name Service (NBNS) to map local resources. 
* The BROWSER Service: The host initiated a Browser Election Request 
  to通 establish a Local Master Browser machine to retain list 
  details of nearby shares.
* Risk Factor: These protocols broadcast unauthenticated requests over 
  the local link. If a rogue device is introduced to this subnet, it 
  can easily spoof answers to these name queries to capture local 
  network traffic or leak hashed corporate credentials.

B. Directory Services & Authentication (Kerberos / DNS)
* Observation: The endpoint queried DNS infrastructure for active 
  directory server identifiers (_ldap._tcp.dc._msdcs) to safely 
  authenticate against the local Domain Controller (10.1.21.2).
* Authentication Handshake: The host generated standard Authentication 
  Service Requests (AS-REQ). Initial passes generated a 
  KRB5KDC_ERR_PREAUTH_REQUIRED status frame, which represents normal 
  Windows validation prior to supplying encrypted timestamps.

----------------------------------------------------------------------
4. RECOMMENDED REMEDIATION & ACTIONS
To secure the baseline environment and mitigate the risks identified 
during this analysis phase, the following hardening steps are advised:

1. Disable LLMNR globally via Active Directory Group Policy Objects 
   (GPO):
   Path: Computer Configuration -> Administrative Templates -> 
         Network -> DNS Client
   Setting: Enable "Turn off multicast name resolution".

2. Disable NetBIOS over TCP/IP (NBNS) directly within the DHCP server 
   options or advanced network adapter settings on local workstations.

3. Deactivate the Computer Browser service across all Windows 
   endpoints via GPO, as it is a legacy feature that relies on 
   unencrypted local discovery mechanisms.

4. Isolate or Monitor Victim Host: If any abnormal outbound 
   communication pattern or malicious post requests are identified 
   targeting unrecognized external IPs, isolate the endpoint from the 
   VLAN segment immediately for forensic cleanup.
======================================================================
