# Project 02 (part 2) – DNS Enumeration with dig tridenttech.edu google.com

## Objective

Use `dig` to enumerate DNS information for two public domains (`tridenttech.edu` and `google.com`), compare the results, and explain what they reveal from a security and reconnaissance point of view.

## Lab Environment

- Attacker system: Kali Linux
- Network: Home lab (outbound internet allowed)
- Tool: `dig` (Domain Information Groper)
- Targets:
  - `tridenttech.edu` – Trident Technical College public website 
  - `google.com` – Public internet service

## Methodology

For each target domain, I ran the same core DNS queries:

- Basic lookup (A record via system resolver)
- Explicit A and AAAA lookups
- MX (mail exchanger) records
- NS (authoritative name servers)
- TXT records
- Reverse lookup (`-x`) on selected IPs
- AXFR (zone transfer) attempt to confirm transfers are blocked

My resolver was my home router/DNS at `192.168.3.1`.

---

## Results – tridenttech.edu

### A / AAAA records

**Commands:**

```bash
dig tridenttech.edu
dig tridenttech.edu A
dig trident.edu AAAA
```

**Snippet:**

```txt
tridenttech.edu. 300 IN A 3.209.26.193
tridenttech.edu. 300 IN A 34.236.193.193
tridenttech.edu. 300 IN A 52.73.2.219
```

- `tridenttech.edu` resolves to three IPv4 addresses, which suggests load balancing or redundancy across multiple backends.
- Querying `trident.edu AAAA` returned no AAAA answers, indicating no IPv6 record is currently published for that hostname.

### MX records

**Command:**

```bash
dig tridenttech.edu MX
```

**Snippet:**

```txt
tridenttech.edu. 300 IN MX  0 mx1.hc6353-14.iphmx.com.
tridenttech.edu. 300 IN MX 10 mx2.hc6353-14.iphmx.com.
```

- Priority 0: `mx1.hc6353-14.iphmx.com` (primary mail server).
- Priority 10: `mx2.hc6353-14.iphmx.com` (backup mail server).
- The `iphmx.com` domain is associated with Cisco’s hosted email security gateway, so Trident is using a cloud email security provider in front of its mail infrastructure.

### NS records

**Command:**

```bash
dig tridenttech.edu NS
```

**Snippet:**

```txt
tridenttech.edu. 76517 IN NS adi.ns.cloudflare.com.
tridenttech.edu. 76517 IN NS guss.ns.cloudflare.com.
```

- The authoritative name servers are Cloudflare (`adi.ns.cloudflare.com`, `guss.ns.cloudflare.com`).
- That means Trident’s DNS is managed by Cloudflare, gaining global anycast DNS and various performance/security benefits.

### TXT records

**Command:**

```bash
dig tridenttech.edu TXT
```

**Selected snippet:**

```txt
tridenttech.edu. 295 IN TXT "v=spf1 include:spf1.tridenttech.edu include:spf2.tridenttech.edu -all"
tridenttech.edu. 295 IN TXT "google-site-verification=..."
tridenttech.edu. 295 IN TXT "jamf-site-verification=..."
tridenttech.edu. 295 IN TXT "MS=ms60380330"
tridenttech.edu. 295 IN TXT "ZOOM_verify_..."
tridenttech.edu. 295 IN TXT "abuseipdb-verification=..."
tridenttech.edu. 295 IN TXT "have-i-been-pwned-verification=..."
...
```

- The SPF record (`v=spf1 ... -all`) states which hosts are allowed to send email for the domain and instructs receivers to reject others (`-all`).
- Numerous `*-verification` TXT entries show integrations with services such as Google, Apple, Zoom, Cisco, Jamf, AbuseIPDB, Duo, Atlassian, Autodesk, and Have I Been Pwned.
- TXT records here give strong hints about which SaaS platforms the college relies on operationally.

### Reverse lookup

**Command (example IP where reverse DNS is not configured):**

```bash
dig -x 199.97.29.98
```

**Snippet:**

```txt
;98.29.97.199.in-addr.arpa. IN PTR
status: NXDOMAIN
29.97.199.in-addr.arpa. 3600 IN SOA auth1.dns.cogentco.com. dns.cogentco.com.
```

- The NXDOMAIN status on the PTR indicates no reverse DNS is configured for that IP.
- Reverse DNS is managed separately from forward A records; missing PTRs can hurt reputation and trigger stricter filtering in some mail/security systems.

### AXFR zone transfer attempt

**Command (conceptual):**

```bash
dig tridenttech.edu AXFR
```

**Result:**

```txt
; Transfer failed: REFUSED
```

- The nameserver refused the AXFR request, which is the expected secure configuration for public DNS.
- Leaving AXFR open would allow anyone to pull the full zone file and enumerate all DNS names in one shot, which is a major recon win for an attacker.

---

## Results – google.com

### A / AAAA records

**Commands:**

```bash
dig google.com
dig google.com A
dig google.com AAAA
```

**A record snippet:**

```txt
google.com. 300 IN A 173.194.219.101
google.com. 300 IN A 173.194.219.113
google.com. 300 IN A 173.194.219.102
google.com. 300 IN A 173.194.219.100
google.com. 300 IN A 173.194.219.138
google.com. 300 IN A 173.194.219.139
```

**AAAA record snippet:**

```txt
google.com. 300 IN AAAA 2607:f8b0:4002:c03::64
google.com. 300 IN AAAA 2607:f8b0:4002:c03::66
google.com. 300 IN AAAA 2607:f8b0:4002:c03::71
google.com. 300 IN AAAA 2607:f8b0:4002:c03::8a
```

- `google.com` publishes multiple IPv4 and IPv6 addresses, typical for a large anycasted and globally load‑balanced service.
- Dual‑stack support means clients on IPv4 and IPv6 can both reach the service efficiently.

### MX records

**Command:**

```bash
dig google.com MX
```

**Snippet:**

```txt
google.com. 300 IN MX 10 smtp.google.com.
```

- Email for `google.com` is routed to `smtp.google.com` with priority 10.
- Unlike Trident’s use of a third‑party gateway, Google handles its own inbound mail through its infrastructure.

### NS records

**Command:**

```bash
dig google.com NS
```

**Snippet:**

```txt
google.com. 76524 IN NS ns1.google.com.
google.com. 76524 IN NS ns2.google.com.
google.com. 76524 IN NS ns3.google.com.
google.com. 76524 IN NS ns4.google.com.
```

- The authoritative name servers are all under `google.com` and are reachable over both IPv4 and IPv6.
- Google operates its own authoritative DNS globally instead of offloading to a provider like Cloudflare.

### TXT records

**Command:**

```bash
dig google.com TXT
```

**Selected snippet:**

```txt
google.com. 300 IN TXT "v=spf1 include:_spf.google.com ~all"
google.com. 300 IN TXT "facebook-domain-verification=..."
google.com. 300 IN TXT "apple-domain-verification=..."
google.com. 300 IN TXT "docusign=..."
google.com. 300 IN TXT "onetrust-domain-verification=..."
google.com. 300 IN TXT "globalsign-smime-dv=..."
...
```

- The SPF record (`v=spf1 include:_spf.google.com ~all`) delegates permitted sending IPs to `_spf.google.com` and uses a soft‑fail (`~all`).
- As with Trident, TXT records double as a machine‑readable integration layer for services like Facebook, Apple, DocuSign, and OneTrust.

### Reverse lookup (PTR)

**Command:**

```bash
dig -x 8.8.8.8
```

**Snippet:**

```txt
8.8.8.8.in-addr.arpa. 76774 IN PTR dns.google.
```

- The PTR record for `8.8.8.8` resolves to `dns.google.`, which is the expected hostname for Google’s public DNS resolver.
- Forward and reverse lookups are consistent, which is good practice for DNS hygiene and mail/server reputation.

### AXFR zone transfer attempt

**Command (conceptual):**

```bash
dig google.com AXFR
```

**Result:**

```txt
; Transfer failed: REFUSED
```

- As with Trident, zone transfer attempts against `google.com` are refused, confirming that full zone dumps are not exposed to arbitrary clients.

---

## Analysis and Comparison

- **IPv4 vs IPv6:** Both domains publish multiple A records for redundancy, but only `google.com` publishes AAAA records on the main hostname I queried, showing full dual‑stack deployment.
- **Mail routing:** Trident uses Cisco’s `iphmx.com` cloud email security gateway as its MX target, while Google terminates mail directly on `smtp.google.com`.
- **DNS providers:** Trident’s authoritative DNS is hosted on Cloudflare name servers, while Google operates its own `ns1`–`ns4.google.com` infrastructure.
- **TXT information leakage:** Both domains’ TXT records expose SPF policies and a long list of third‑party SaaS integrations, which is useful OSINT in a recon phase.
- **Hardening:** AXFR zone transfers are refused for both domains, preventing attackers from trivially dumping the entire DNS zone and mapping internal hostnames.

## What I Learned

- Running the same `dig` playbook against two different public domains made it obvious how DNS design reflects an organization’s size and risk posture.
- TXT records are a goldmine for OSINT, exposing email configuration (SPF) and which SaaS providers an organization trusts.
- Reverse DNS (PTR) is separate from forward A/AAAA records and matters for things like mail reputation and security analytics.
- Secure DNS configurations refuse AXFR to arbitrary clients; leaving AXFR open would dramatically speed up attacker reconnaissance and exposure of internal hostnames.
