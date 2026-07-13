# Phase 3: Live Decryption Analysis & Protocol Inspection

##  Executive Summary
* **Goal:** Apply logged TLS secrets to actively decrypt live streams and inspect upper-layer application protocols (HTTP/2, TLS Handshake extensions).
* **Environment:** `gideon930@ajones` / Kali-Attacker VM
* **Status:** SUCCESSFUL

---

## Decryption Verification & Traffic Analysis
With the `ssl-keylog.log` file successfully mapped to Wireshark, the following packet details were exposed:

### Protocol Visibility Comparison
| Layer | Pre-Decryption State | Post-Decryption State |
| :--- | :--- | :--- |
| **Transport Layer** | TCP / UDP (Port 443) | TCP (Port 443) |
| **Security Layer** | TLSv1.3 (Encrypted Application Data) | TLSv1.3 / Decrypted TLS |
| **Application Layer** | None (Hidden) | HTTP/2 / JSON / HTML |

### Key Findings & Exposed Data
* **Inspected Host:** `github.com` (via endpoints such as `copilot-budget-req` and `top_repositories`)
* **Application Layer Protocol:** HTTP/2
* **Exposed Headers:** GET requests detected for `/dashboard/my_top_repositories` and `/in-product-messaging/copilot-budget-req`. Header block fragments revealed client environment markers (`sec-ch-ua-platform: "Linux"`, `sec-ch-ua: "Chromium"`).
* **Payload Content:** Reassembled 4 encrypted TLS segments (4973 bytes total) revealing plain-text `HEADERS` and `DATA` streams on Stream ID: 3.

---

## Deep-Dive: TLS 1.3 Handshake Inspection & Method Behavior
Using the decrypted data stream, the exact parameters of the modern cryptographic handshake and subsequent application behaviors were analyzed:

* **Supported Versions:** The Client Hello explicitly advertised `TLS 1.3 (0x0304)`.
* **Cipher Suite Negotiated:** `TLS_AES_256_GCM_SHA384`
* **Encrypted Extensions:** Verified that certificate exchanges and handshake modifications were fully visible in the decrypted packet pane rather than showing as "Encrypted Handshake Message."
* **Observed HTTP Methods:** Both `GET` and `POST` requests were successfully uncovered. Unencrypted metrics tracking via `POST /_private/browser/stats` (Packet 165) was exposed in plaintext.
* **Stream Multiplexing:** Documented multi-stream data transport over a single TCP connection, specifically observing cleartext `HEADERS` and payload queries negotiating simultaneously over Stream ID: 3.

---

## Technical Challenges & Sandboxing Obstacles
During the initial deployment of Phase 3, several critical environment-level roadblocks were encountered and systematically resolved:

### Path Mapping Syntax Restriction
* **The Problem:** The initial execution script resulted in immediate browser instantiation errors or a complete failure to generate the key logs.
* **The Root Cause:** A syntax error occurred in the terminal script string where a hyphen (`-`) was accidentally utilized instead of a tilde (`~`) to represent the path shortcut (`export SSLKEYLOGFILE=-/ssl-keylog.log`). Linux environments parsed the hyphen as a literal, non-existent folder directory named `-`.
* **The Resolution:** Corrected the parameter to map directly to an absolute path string format (`/home/gideon/sslkeys/ssl-keylog.log`) to guarantee explicit tracking.

### The Snap Sandbox Restriction (The Environment Disconnect)
* **The Problem:** Setting standard, generic environment paths (like exporting to global directories such as `/tmp/ssl-keylog.log`) failed to yield any decrypted `http` or `http2` packets in Wireshark. The target log file remained completely empty.
* **The Root Cause:** Modern Ubuntu/Debian distributions package browsers like Chromium as isolated **Snap packages**. Applications managed under Snap operate inside strict AppArmor container environments. This security design explicitly blocks the browser binary from executing write operations to global or system-level root directories, ignoring our target variable parameters.
* **The Resolution:** The session path was explicitly redirected to a subdirectory owned entirely by the local user profile (`/home/gideon/sslkeys/ssl-keylog.log`). Because the Snap container layout permits write access within the user's home partition structure, Chromium successfully began streaming the pre-master secrets.

### Process Isolation & Session Hijacking
* **The Problem:** Even after mapping valid home paths, terminal executions frequently triggered an application warning: `Opening in existing browser session`. 
* **The Root Cause:** Chromium enforces aggressive session isolation. If a background component, orphaned instance, or alternative browser frame is already initialized under the operating system, issuing a new execution command simply binds a tab to the preexisting PID—entirely bypassing the newly exported environment configurations.
* **The Resolution:** All active desktop and hidden application instances were completely terminated. Re-running the sequence cleanly forced a pristine process initialization that correctly bound to the key logs.

### Protocol Bypassing (HTTP/3 / QUIC over UDP)
* **The Problem:** Initial packet stream analyses showed targeted application layers leaking encrypted data blocks despite mapping valid key strings.
* **The Root Cause:** Modern edge networks automatically attempt to upgrade connection streams to use HTTP/3 running over the QUIC protocol. Because QUIC multiplexes connection data using UDP states rather than traditional TCP handshakes, standard TLS decryption filters failed to parse the streams.
* **The Resolution:** Appended the explicit `--disable-quic` operational runtime flag to the command. This forced the Chromium instance to fallback to standard, TCP-bound HTTP/2 streams, allowing Wireshark to match the pre-master secrets file and expose the data frames cleanly.
