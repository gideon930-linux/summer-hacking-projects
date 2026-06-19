# Project 02 – DNS Enumeration

## Objective

Use basic DNS tools to enumerate records for a safe test domain and understand what information DNS can reveal about a target’s infrastructure.

## Lab Environment

- Attacker: Kali Linux
- Resolver: Homelab DNS via OPNsense (192.168.3.1)
- Target domain: `example.com` (reserved documentation domain, safe for practice)

---

## Step 1 – Forward Lookups with dig

### A Records (IPv4 addresses)

Command:

```bash
dig example.com
```

Key output (ANSWER section):

```text
example.com. 300 IN A 104.20.23.154
example.com. 300 IN A 172.66.147.243
```

Interpretation:

- `A` = IPv4 address record.
- `example.com` resolves to **two IPv4 addresses**:
  - 104.20.23.154
  - 172.66.147.243
- `300` is the TTL (Time To Live) in seconds – caches can keep this answer for 5 minutes.
- Having multiple A records usually means load balancing or redundancy in front of the site.

These IPs are the front‑end hosts a client actually connects to when visiting `example.com`.

### NS Records (Name Servers)

Command:

```bash
dig NS example.com
```

Key output (ANSWER section):

```text
example.com. 86400 IN NS elliott.ns.cloudflare.com.
example.com. 86400 IN NS hera.ns.cloudflare.com.
```

Interpretation:

- `NS` = Name Server records.
- `elliott.ns.cloudflare.com` and `hera.ns.cloudflare.com` are the **authoritative DNS servers** for `example.com`.
- TTL is 86400 seconds (24 hours).
- This tells us that Cloudflare is providing DNS for this domain.

In a real engagement, NS records show which provider runs DNS and can hint at where to check for misconfigurations or zone transfer issues.

### MX Records (Mail Servers)

Command:

```bash
dig MX example.com
```

Key output (ANSWER section):

```text
example.com. 300 IN MX 0 .
```

Interpretation:

- `MX` = Mail Exchanger records (where email for the domain is delivered).
- Priority `0` with a host of `.` is a **null MX record**.
- This explicitly means **`example.com` does not accept email**.
- Mail servers seeing this record know not to try delivering messages to addresses like `user@example.com`.

---

## Step 2 – Automated Enumeration with dnsenum

Command:

```bash
dnsenum example.com
```

### Host Addresses

`dnsenum` confirms the same A records:

```text
example.com. 300 IN A 172.66.147.243
example.com. 300 IN A 104.20.23.154
```

This matches the output from `dig example.com` and confirms our forward lookups.

### Name Servers and Their IPs

```text
elliott.ns.cloudflare.com. 86353 IN A 108.162.195.228
elliott.ns.cloudflare.com. 86353 IN A 172.64.35.228
elliott.ns.cloudflare.com. 86353 IN A 162.159.44.228
hera.ns.cloudflare.com.    86353 IN A 173.245.58.162
hera.ns.cloudflare.com.    86353 IN A 172.64.32.162
hera.ns.cloudflare.com.    86353 IN A 108.162.192.162
```

Interpretation:

- `dnsenum` took the NS names and resolved them to their own IP addresses.
- Each Cloudflare name server has multiple anycast IPs for redundancy and global coverage.
- This is useful to see which networks / ranges a provider uses for DNS.

### Zone Transfer Attempts

```text
Trying Zone Transfer for example.com on elliott.ns.cloudflare.com ...
AXFR record query failed: FORMERR

Trying Zone Transfer for example.com on hera.ns.cloudflare.com ...
AXFR record query failed: FORMERR
```

Interpretation:

- `dnsenum` tried an **AXFR (zone transfer)** on each name server.
- A successful AXFR would dump the entire DNS zone file (huge recon win), but here:
  - Both attempts failed with `FORMERR`, which is expected on a properly configured public DNS service.
- From a defensive point of view, this is **good** – open zone transfers would be a misconfiguration.

### Subdomain Brute Forcing

```text
Brute forcing with /usr/share/dnsenum/dns.txt:
www.example.com. 300 IN A 172.66.147.243
www.example.com. 300 IN A 104.20.23.154
```

Interpretation:

- `dnsenum` used a wordlist to try common subdomains (www, mail, vpn, api, etc.).
- It discovered `www.example.com`, which resolves to the same IPs as the root domain.
- In real targets, this technique can reveal important subdomains like:
  - `api.example.org`
  - `vpn.example.org`
  - `dev.example.org`

### Class C Ranges and Reverse Lookups

```text
example.com class C netranges:
 104.20.23.0/24
 172.66.147.0/24

Performing reverse lookup on 512 ip addresses:
0 results out of 512 IP addresses.
```

Interpretation:

- `dnsenum` identified the /24 networks containing the A records (`104.20.23.0/24`, `172.66.147.0/24`).
- It then tried PTR (reverse DNS) lookups across those ranges to discover additional hostnames.
- `0 results` means reverse DNS isn’t exposing useful hostnames in these ranges, which is common for large CDN providers.

---

## Step 3 – Reverse DNS (PTR) with dig

### Incorrect PTR Query on the Domain Name

Command:

```bash
dig PTR example.com
```

Key output:

```text
;; ANSWER: 0, AUTHORITY: 1

;; QUESTION SECTION:
;example.com. IN PTR

;; AUTHORITY SECTION:
example.com. 1800 IN SOA elliott.ns.cloudflare.com. dns.cloudflare.com. ...
```

Interpretation:

- PTR records are for **reverse lookups (IP → name)** and usually live under `in-addr.arpa`, not directly on the domain name.
- Asking for `PTR example.com` returns no answer and just the **SOA** (Start of Authority) for the zone.
- The SOA confirms Cloudflare as the DNS operator and includes:
  - Primary NS: `elliott.ns.cloudflare.com`
  - Contact: `dns@cloudflare.com` (encoded as `dns.cloudflare.com.` in DNS format)
  - Serial and timing values for zone replication.

This shows why PTR lookups should be done on IP addresses, not on the domain name itself.

### Correct Reverse Lookup on an IP

Command:

```bash
dig -x 104.20.23.154
```

Key output:

```text
;; QUESTION SECTION:
;154.23.20.104.in-addr.arpa. IN PTR

;; ANSWER SECTION:
# (none)

;; AUTHORITY SECTION:
20.104.in-addr.arpa. 3600 IN SOA cruz.ns.cloudflare.com. dns.cloudflare.com. ...
```

Interpretation:

- `-x` builds the reverse name `154.23.20.104.in-addr.arpa.` and queries for a PTR.
- `status: NXDOMAIN` and no ANSWER section means **there is no PTR record** for that IP.
- The SOA shows that Cloudflare also manages the reverse zone `20.104.in-addr.arpa`.

Takeaway:

- Forward DNS (A records) shows us the IPs for `example.com`.
- Reverse DNS (PTR records) is optional; for this IP, no PTR is published.
- In some environments, PTRs reveal internal hostnames; here, they don’t.

---

## Lessons Learned

- `dig` is a low‑level DNS tool that lets you inspect specific record types:
  - `A` → IPv4 addresses
  - `NS` → authoritative name servers
  - `MX` → mail servers (null MX `0 .` means “no mail here”)
  - `PTR` + `-x` → reverse DNS lookups
- `example.com` is a safe, reserved domain for documentation and labs; using it avoids probing random real‑world targets.
- `dnsenum` automates many DNS lookups:
  - Confirms A, NS, and MX information
  - Attempts zone transfers (AXFR) to detect misconfigurations
  - Brute‑forces common subdomains
  - Tries reverse lookups over discovered IP ranges
- In this case:
  - DNS reveals Cloudflare as the DNS and reverse DNS provider.
  - The domain exposes two front‑end IPs and one subdomain (`www.example.com`).
  - Null MX and failed AXFR attempts indicate a fairly locked‑down, well‑managed DNS setup.
- Combining `dig` and `dnsenum` gives a repeatable DNS recon workflow you can re‑use on lab domains you own or are authorized to test.

## Files Created

- `dnsenum-example.com.txt` or terminal capture (if you save the output)
- `dig-example.com.txt` (optional saved output of your dig commands)
- `02-dns-enumeration.md` (this writeup)
