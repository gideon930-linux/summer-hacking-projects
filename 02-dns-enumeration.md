# Project 02 – DNS Enumeration with `dig`

## Objective

Use the `dig` command to enumerate DNS records for a target domain, perform reverse lookups, query a specific DNS server, and trace the full DNS resolution path. The goal is to understand how DNS infrastructure exposes information about a domain in a controlled, read‑only way.

## Lab Environment

- Attacker machine: Kali Linux
- Resolver used by default: `192.168.3.1` (lab DNS / router)
- Target domain: `example.com` (safe test domain)
- Time of tests: Sat Jun 20, 2026

---

## 1. A Record Lookups

### 1.1 Full output A record query

**Command**

```bash
dig example.com
```

**Key output**

```text
;; QUESTION SECTION:
;example.com.                   IN      A

;; ANSWER SECTION:
example.com.            300     IN      A       172.66.147.243
example.com.            300     IN      A       104.20.23.154
```

**Notes**

- `example.com` resolves to two IPv4 addresses: `172.66.147.243` and `104.20.23.154`.
- TTL of `300` seconds indicates the time the answer can be cached.
- The `SERVER` line shows `192.168.3.1#53`, meaning the query went through the lab DNS/router.

### 1.2 Short A record output

**Command**

```bash
dig example.com +short
```

**Output**

```text
104.20.23.154
172.66.147.243
```

**Notes**

- `+short` is useful when you just need the IPs without headers, which is great for scripts or quick checks.

---

## 2. MX, NS, and TXT Records

### 2.1 MX (Mail Exchange) records

**Command**

```bash
dig example.com MX
```

**Key output**

```text
;; QUESTION SECTION:
;example.com.                   IN      MX

;; ANSWER SECTION:
example.com.            300     IN      MX      0 .
```

**Notes**

- MX `0 .` is a special configuration that effectively says “this domain does not accept mail”, which is expected for `example.com`.

### 2.2 NS (Name Server) records

**Command**

```bash
dig example.com NS
```

**Key output**

```text
example.com.            86400   IN      NS      elliott.ns.cloudflare.com.
example.com.            86400   IN      NS      hera.ns.cloudflare.com.
```

**Notes**

- The authoritative nameservers for `example.com` are Cloudflare servers:
  - `elliott.ns.cloudflare.com`
  - `hera.ns.cloudflare.com`
- This tells you which provider hosts DNS for the domain.

### 2.3 TXT records

**Command**

```bash
dig example.com TXT
```

**Key output**

```text
example.com.            300     IN      TXT     "_k2n1y4vw3qtb4skdx9e7dxt97qrmmq9"
example.com.            300     IN      TXT     "v=spf1 -all"
```

**Notes**

- `v=spf1 -all` is an SPF record that indicates there are **no authorized email senders** for this domain.
- TXT records often contain SPF, verification tokens, and other metadata.

---

## 3. Reverse DNS Lookup

### 3.1 PTR record for a known IP

**Command**

```bash
dig -x 8.8.8.8
```

**Key output**

```text
;; QUESTION SECTION:
;8.8.8.8.in-addr.arpa.          IN      PTR

;; ANSWER SECTION:
8.8.8.8.in-addr.arpa.   86400   IN      PTR     dns.google.
```

**Notes**

- The reverse lookup for `8.8.8.8` returns `dns.google.`, confirming it belongs to Google Public DNS.

---

## 4. Querying a Specific DNS Server

### 4.1 Asking Google’s resolver directly

**Command**

```bash
dig @8.8.8.8 example.com
```

**Key output**

```text
;; QUESTION SECTION:
;example.com.                   IN      A

;; ANSWER SECTION:
example.com.            300     IN      A       172.66.147.243
example.com.            300     IN      A       104.20.23.154

;; SERVER: 8.8.8.8#53(8.8.8.8) (UDP)
```

**Notes**

- This bypasses the lab DNS/router and asks Google’s resolver directly.
- The A records match the earlier results, which is a good consistency check.

---

## 5. Tracing the Full DNS Resolution Path

### 5.1 `+trace` from root to authoritative server

**Command**

```bash
dig example.com +trace
```

**Key behavior**

- Starts at the root (`.`) servers and shows NS records for them.
- Then shows `.com` TLD servers (e.g., `a.gtld-servers.net`, `e.gtld-servers.net`).
- Finally shows the authoritative nameservers for `example.com`:
  - `hera.ns.cloudflare.com.`
  - `elliott.ns.cloudflare.com.`
- Ends with the A records:

  ```text
  example.com. 300 IN A 104.20.23.154
  example.com. 300 IN A 172.66.147.243
  ```

**Notes**

- You see some `UDP setup ... failed: network unreachable` messages for IPv6 addresses; this just means your machine doesn’t have IPv6 connectivity to those servers and falls back to IPv4.
- `+trace` is a good way to visualize the delegation chain and debugging resolution problems.

---

## 6. Summary / Lessons Learned

- `dig` can retrieve different record types (A, MX, NS, TXT) with a simple change to the record type argument.
- `+short` is ideal for scripting or quick lookups when you only need the answer, not the headers.
- Reverse lookups with `-x` reveal PTR hostnames, which can help with attribution and troubleshooting.
- Using `@<server>` lets you compare what different resolvers (e.g., your router vs Google DNS) return.
- `+trace` walks through the entire resolution path from the root servers to the authoritative DNS servers, which helps understand DNS hierarchy and troubleshoot issues.
- The outputs for `example.com` looked different (MX of `0 .`, SPF `-all`) because it is a special test domain, not a normal mail‑receiving domain.

---

## Commands Used (Reference)

```bash
# Basic A record with full output
dig example.com

# Short output
dig example.com +short

# MX, NS, TXT records
dig example.com MX
dig example.com NS
dig example.com TXT

# Reverse lookup for a known IP
dig -x 8.8.8.8

# Query a specific DNS server directly
dig @8.8.8.8 example.com

# Trace full resolution path
dig example.com +trace
```
