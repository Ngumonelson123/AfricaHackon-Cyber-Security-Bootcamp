# C1A: Exploring Domains & Subdomains

AfricaHackon Training assignment — subdomain reconnaissance against `africahackon.com`, classifying live vs dead hosts and fingerprinting WAF/firewall configuration.

**Full write-up:** [C1A-Subdomain-Recon-Report.pdf](C1A-Subdomain-Recon-Report.pdf)

## Summary

- **44** unique subdomains discovered
- **32** live (30 HTTP-responsive, 2 resolve in DNS only)
- **12** dead (no DNS record)
- Most public subdomains sit behind **Cloudflare** (WAF + CDN); `intel` and `learnlinux` run on **Vercel**; a handful (`talent`, and the LiteSpeed-only group) are hosted directly on A2 Hosting/Hostinger behind only a host-level firewall, with no CDN-based WAF in front

## Tools used

| Tool | Role |
|---|---|
| [subfinder](https://github.com/projectdiscovery/subfinder) | Passive subdomain enumeration |
| [assetfinder](https://github.com/tomnomnom/assetfinder) | Passive subdomain enumeration (independent source set) |
| crt.sh | Certificate transparency log lookup |
| [Sublist3r](https://github.com/aboul3la/Sublist3r) | Search-engine-based passive enumeration |
| [OWASP Amass](https://github.com/owasp-amass/amass) | Passive enumeration + ASN/hosting-provider correlation |
| [dnsx](https://github.com/projectdiscovery/dnsx) | DNS resolution — live vs dead classification |
| [httpx](https://github.com/projectdiscovery/httpx) | HTTP probing — status, title, server, tech/WAF detection |
| [wafw00f](https://github.com/EnableSecurity/wafw00f) | Dedicated WAF fingerprinting |
| [WhatWeb](https://github.com/urbanadventurer/WhatWeb) | Technology/header fingerprinting cross-check |
| [Nmap](https://nmap.org/) | Network-layer port scan for firewall/filtering behavior |

## Folder contents

```
recon-tools/
├── C1A-Subdomain-Recon-Report.pdf   # full submitted report
├── all_subdomains.txt               # deduplicated master subdomain list (44)
├── resolved_hosts.txt               # subdomains that resolve via DNS (32)
├── dead_subdomains.txt              # subdomains with no DNS record (12)
├── http_alive_hosts.txt             # subdomains that responded over HTTP (30)
├── summary_table.md                 # per-subdomain status + WAF/proxy layer table
├── screenshots/                     # terminal-style renders of each tool's output, embedded in the PDF
└── raw/                             # full untruncated output from every tool run
```

## Reproducing the scan

```bash
# Enumeration
subfinder -d africahackon.com -silent
assetfinder --subs-only africahackon.com
curl -s "https://crt.sh/?q=%.africahackon.com&output=json" | jq -r '.[].name_value'
sublist3r -d africahackon.com
amass enum -passive -d africahackon.com

# Liveness
dnsx -l all_subdomains.txt -a -resp -silent
httpx -l resolved_hosts.txt -sc -title -server -tech-detect -location -silent

# Firewall / WAF
wafw00f https://<subdomain>.africahackon.com
whatweb -a 3 https://<subdomain>.africahackon.com
nmap -Pn -F <subdomain>.africahackon.com
```

## Scope note

All testing was passive or lightweight active reconnaissance (DNS queries, certificate transparency lookups, single HTTP requests, a fast top-port Nmap scan) against AfricaHackon's own training domain, as assigned by AfricaHackon Training. No exploitation, brute-forcing, or intrusive testing was performed.
