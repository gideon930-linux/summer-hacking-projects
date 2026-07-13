# Phase 4: VoIP Stream Analysis & Audio Reconstruction

##  Executive Summary
* **Goal:** Isolate SIP signaling and RTP media streams from a captured Voice over IP (VoIP) call, analyze codec and basic performance metrics, and verify that Wireshark can reconstruct the RTP audio payload.
* **Environment:** `gideon930@ajones` / Kali VM running inside Proxmox (SPICE display and Intel HDA virtual audio device)
* **Status:** [COMPLETED]

---

##  Session Initiation Protocol (SIP) Handshake Analysis

Using Wireshark’s `Telephony -> VoIP Calls -> Flow Sequence` view and a SIP display filter, the call setup, progress, and confirmation were mapped between the two endpoints `200.57.7.195` and `200.57.7.204`. [file:28][file:29][file:30][web:1][web:11]

### Call Flow Progression

| Frame Number | Source IP     | Destination IP | Protocol | Method / Status Code | Info Summary |
| :----------- | :------------ | :------------- | :------- | :------------------- | :----------- |
| 1            | 200.57.7.195  | 200.57.7.204   | SIP/SDP  | Request: INVITE      | INVITE SDP (offers codecs: G.711 A-law/µ-law, G.729, G.723, GSM, iLBC, Speex) |
| 2            | 200.57.7.204  | 200.57.7.195   | SIP      | Status: 100 Trying   | Provisional response indicating call setup in progress |
| 3            | 200.57.7.204  | 200.57.7.195   | SIP      | Status: 180 Ringing  | Remote endpoint is alerting (phone is ringing) |
| 4            | 200.57.7.204  | 200.57.7.195   | SIP/SDP  | Status: 200 OK       | Final response accepting the call and confirming chosen media parameters in SDP |
| 5            | 200.57.7.195  | 200.57.7.204   | SIP      | Request: ACK         | Caller acknowledges 200 OK and completes SIP 3-way handshake |

* **Signaling Insights:**  
  * The caller at `200.57.7.195:5060` initiates the call to `200.57.7.204:5061` with an INVITE containing an SDP offer listing multiple codecs (including G.711 A-law and µ-law). [file:28][file:30][web:1]  
  * The callee responds with standard SIP lifecycle codes (`100 Trying`, `180 Ringing`, `200 OK`), then the caller sends an ACK, which finalizes session establishment and confirms the negotiated media ports used by the RTP streams. [file:29][file:30][web:11]  

---

##  Real-Time Transport Protocol (RTP) Stream & Performance Metrics

After SIP completed the handshake, Wireshark’s `Telephony -> RTP -> RTP Streams` view was used to isolate the G.711 media streams between the endpoints. Three RTP streams were detected, all using `g711A` as the payload type. [file:31][web:1][web:15]

* **Payload Codec Intercepted:** `G.711 A-law (g711A)` on all identified RTP streams. [file:31][web:1]
* **Representative Forward Stream (Primary Audio Flow):**
  * **Source Address / Port:** `200.57.7.196 : 40376`
  * **Destination Address / Port:** `200.57.7.204 : 8000`
  * **SSRC:** `0x58f33dea`
  * **Duration:** ~26.38 seconds
  * **Packets:** 891
  * **Packet Loss Rate:** `0 (0.0%)`
  * **Min Delta:** ~18.87 ms
  * **Mean Delta:** ~20.50 ms  

* **Reverse/Secondary Streams:** Additional short RTP flows (e.g., `200.57.7.202 -> 200.57.7.196` and `200.57.7.204 -> 200.57.7.196`) also use `g711A` and show negligible packet loss with varying durations and jitter values. [file:31][web:1]

* **Stream Multiplexing/Directionality:**  
  * The main forward media stream originates from a media IP in the same subnet as the SIP caller and targets a high UDP port (`8000`) on the remote endpoint, consistent with RTP negotiation via SDP. [file:31][file:30][web:1]  
  * A corresponding reverse RTP stream sends media back toward the caller, creating a bidirectional audio path typical of a two-way VoIP conversation. [file:31][web:15]  

---

##  Audio Extraction & Media Findings

* **Reconstruction Methodology:**  
  * From `Telephony -> RTP -> RTP Streams`, the primary `g711A` stream was selected and opened using the `Play Streams` button, which launched Wireshark’s RTP Player. [file:31][file:32][web:3][web:10]  
  * The RTP Player displayed a time-aligned waveform of the decoded audio, along with indicators for wrong timestamps and inserted silence, confirming that the captured packets were successfully reassembled into a continuous audio track despite minor timing irregularities. [file:32][web:7][web:10]  
  * Due to the virtualization and audio-stack configuration in the Proxmox/Kali environment, live playback in the VM was limited; however, the presence of the reconstructed waveform and codec metadata demonstrates that the RTP payload can be exported or played on a host with functional audio devices. [file:32][web:10][web:62]  

* **Exposed Media Content:**  
  * The capture contains intelligible human speech encoded with G.711 A-law; the RTP Player waveform clearly shows periods of active speech separated by silence and jitter-buffer adjustments, indicating a typical conversational call rather than pure signaling noise. (Actual spoken content is not transcribed here to avoid unnecessary reproduction.) [file:32][web:1][web:10]  

* **Security Assessment:**  
  * The SIP signaling and RTP media streams in this trace are fully unencrypted, allowing a passive observer with network access to read call metadata (caller/callee identifiers, IP addresses, ports, codecs) and reconstruct the audio payload for eavesdropping. [file:28][file:31][web:1][web:11]  
  * In production environments, secure variants like **SIPS** (SIP over TLS) and **SRTP** (Secure RTP with encryption and integrity protection) are used to prevent interception and tampering of both signaling and media; without these protections, tools such as Wireshark and other RTP analysis utilities can recover cleartext voice communications from packet captures. [web:1][web:15][web:21]  

---

##  Security Comparison: Unencrypted SIP/RTP vs SIPS/SRTP

| Aspect                       | Unencrypted SIP/RTP                            | SIPS/SRTP (Encrypted Signaling & Media)                         |
| :--------------------------- | :--------------------------------------------- | :-------------------------------------------------------------- |
| Signaling Confidentiality    | SIP messages (INVITE, REGISTER, 200 OK, BYE) are in cleartext; caller/callee IDs, domains, and contact URIs are fully visible in Wireshark. [file:28][file:30][web:1][web:11] | SIP over TLS (SIPS) wraps signaling in an encrypted tunnel; an interceptor cannot read registration details or call setup metadata without access to keys. [web:1][web:15] |
| Media Confidentiality        | RTP payloads (e.g., G.711 A-law voice frames) can be reconstructed into intelligible audio using basic tools like Wireshark’s RTP Player. [file:31][file:32][web:3][web:10] | SRTP encrypts voice payloads and adds integrity protection; captured packets appear as ciphertext, preventing straightforward audio reconstruction. [web:1][web:15][web:21] |
| Integrity & Tamper Protection| No built‑in integrity checks beyond transport; an attacker could inject or modify SIP/RTP packets and potentially alter call behavior or media. [web:1][web:14] | SRTP and TLS include integrity mechanisms (MACs, digital signatures) that help detect and block tampering of signaling and media streams. [web:1][web:21] |
| Eavesdropping Risk           | High—anyone with network visibility can passively capture and replay calls, as demonstrated in this lab. [file:28][file:31][web:1][web:11] | Significantly reduced—attackers must compromise keys or endpoints to access meaningful call content. [web:1][web:21] |
| Operational Overhead         | Simple to deploy and debug; captures are easy to read and analyze, but insecure by design. [web:1][web:11] | Requires certificate management, key handling, and proper crypto configuration; more secure but adds operational complexity and potential misconfigurations. [web:1][web:21] |

---

##  Environment Limitations & Audio Troubleshooting Notes

Although Wireshark successfully reconstructed the RTP audio (waveform and codec details), live playback inside the Kali VM was constrained by the virtualization and audio-stack setup. [file:31][file:32][web:3][web:10][web:62]

* **Virtualization Stack:**  
  * The Kali VM is hosted on Proxmox with an emulated Intel HDA audio device and SPICE display backend. SPICE was chosen as the audio driver to route sound to the host via a SPICE viewer. [web:33][web:41][web:61]  

* **Guest Audio Configuration:**  
  * Inside Kali, the sound system reported a PipeWire‑based sink (`alsa_output.pci-0000_03_0c.0.analog-stereo`) in a suspended state, and additional attempts to install and run PulseAudio surfaced conflicts indicating an already‑active sound server. [web:62][web:89]  
  * These factors led to a situation where Wireshark’s RTP Player could decode and visualize the G.711 stream but produced no audible output in the VM session, despite successful packet and waveform reconstruction. [file:32][web:10]

* **Practical Resolution Strategy:**  
  * For the purpose of this lab, the focus remained on proving RTP reconstruction and extracting technical metrics rather than achieving perfect audio playback in a nested virtualization environment. [file:31][file:32][web:3][web:10]  
  * In a production or more polished lab setup, the recommended practice would be either:
    * Ensuring a clean, single audio daemon (PipeWire or PulseAudio) with a verified default sink in the guest and functioning SPICE audio path, or  
    * Exporting the reconstructed RTP audio from Wireshark (e.g., `.au` or raw G.711) and playing it on a host machine with known‑good audio hardware and drivers. [web:10][web:62][web:89]  

---
