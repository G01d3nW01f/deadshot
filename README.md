# DeadShot

**DeadShot** is an internal domain intelligence tool written in Bash. It automates passive subdomain enumeration, DNS resolution, HTTP/HTTPS service discovery, and change detection between scan results.

It is designed for authorized domain reconnaissance and helps security teams monitor their domain infrastructure over time.

## Features

- **Passive Subdomain Enumeration**
  - Uses [Subfinder](https://github.com/projectdiscovery/subfinder) to discover subdomains.

- **Root Domain Inclusion**
  - Automatically includes the specified root domain in the scan.

- **Domain Scope Validation**
  - Filters discovered domains to ensure that only the specified target domain and its subdomains are processed.

- **DNS Resolution**
  - Uses [dnsx](https://github.com/projectdiscovery/dnsx) to resolve A and AAAA records.

- **Wildcard DNS Filtering**
  - Enables automatic wildcard detection to reduce potentially misleading DNS results.

- **HTTP/HTTPS Service Discovery**
  - Uses [httpx](https://github.com/projectdiscovery/httpx) to check both HTTP and HTTPS endpoints.

- **Change Detection**
  - Compares current scan results against the previous snapshot to identify newly discovered and disappeared hosts.

- **Persistent Snapshots**
  - Maintains the latest DNS-resolved host list for future comparisons.

- **Timestamped Results**
  - Saves individual scan results with timestamps to maintain historical records.

## Requirements

The following tools must be installed:

| Tool | Purpose |
|------|---------|
| Bash | Script execution |
| Subfinder | Passive subdomain enumeration |
| dnsx | DNS resolution |
| httpx | HTTP/HTTPS probing |
| Go | Required to locate the httpx binary |
| sort | Sorting and deduplication |
| awk | Text processing |
| comm | Snapshot comparison |
| date | Timestamp generation |
| mkdir | Directory creation |
| mktemp | Temporary directory creation |
| cp | File copying |

### Installing ProjectDiscovery Tools

Install the required tools using Go:

```bash
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
```

Make sure the Go binary directory is available in your environment.

DeadShot expects the httpx binary at:

```bash
$(go env GOPATH)/bin/httpx
```

## Installation

Clone the repository:

```bash
git clone https://github.com/USERNAME/DeadShot.git
cd DeadShot
```

Make the script executable:

```bash
chmod +x deadshot.sh
```

## Usage

```bash
./deadshot.sh <targetdomain>
```

### Example

```bash
./deadshot.sh example.com
```

The target must be a valid fully qualified domain name (FQDN).

## Workflow

DeadShot performs the following operations:

1. Validate the target domain.
2. Check required dependencies.
3. Create the output directory.
4. Discover subdomains using Subfinder.
5. Include the root domain.
6. Filter and deduplicate domain candidates.
7. Resolve A and AAAA records using dnsx.
8. Apply wildcard DNS filtering.
9. Probe HTTP/HTTPS services using httpx.
10. Compare current results with the previous snapshot.
11. Identify new and disappeared hosts.
12. Update the persistent snapshot.
13. Display the scan summary.

## Output Structure

DeadShot automatically creates a results directory for each target domain.

Example:

```text
deadshot_results/
└── example.com/
    ├── domain_scan_20261125_120000_12345.txt
    ├── dns_records_20261125_120000_12345.txt
    ├── alive_list_20261125_120000_12345.txt
    ├── new_hosts_20261125_120000_12345.txt
    ├── disappeared_hosts_20261125_120000_12345.txt
    ├── http_list_20261125_120000_12345.txt
    └── latest_alive_list.txt
```

### Output Files

| File | Description |
|------|-------------|
| `domain_scan_<timestamp>.txt` | Filtered and deduplicated subdomain candidates |
| `dns_records_<timestamp>.txt` | DNS resolution results, including IP addresses |
| `alive_list_<timestamp>.txt` | Hosts with successful DNS resolution |
| `new_hosts_<timestamp>.txt` | Newly discovered DNS-resolved hosts |
| `disappeared_hosts_<timestamp>.txt` | Previously resolved hosts that no longer resolve |
| `http_list_<timestamp>.txt` | Discovered HTTP/HTTPS endpoints |
| `latest_alive_list.txt` | Persistent snapshot used for future comparisons |

## Change Detection

DeadShot compares the current DNS-resolved host list with the previous snapshot.

### New Hosts

Hosts that appear in the current scan but were not present in the previous snapshot.

Example:

```text
api.example.com
dev.example.com
staging.example.com
```

### Disappeared Hosts

Hosts that were present in the previous snapshot but are absent from the current DNS resolution results.

Example:

```text
old.example.com
legacy.example.com
```

### Initial Scan

During the first execution, no previous snapshot exists.

DeadShot automatically creates the initial baseline and records all DNS-resolved hosts as new hosts.

Subsequent executions use this baseline for comparison.

## Example Output

```text
[DeadShot] Starting subdomain enumeration: example.com
[DeadShot] Candidates: 25
[DeadShot] Resolving A / AAAA records with dnsx
[DeadShot] Checking HTTP / HTTPS services with httpx
[DeadShot] HTTP / HTTPS endpoints: 12
[DeadShot] Comparing with previous snapshot

[DeadShot] Scan completed
------------------------------------------
Target domain : example.com
Candidates    : 25
DNS resolved  : 18
New hosts     : 3
Disappeared   : 2
------------------------------------------
```

*Note: This is an illustrative example. Actual results depend on the target domain and DNS configuration.*

## Security Considerations

DeadShot is intended for authorized security assessments and internal domain monitoring.

- Only scan domains that you own or have explicit permission to assess.
- Passive enumeration does not guarantee complete subdomain discovery.
- DNS resolution results may change due to temporary network conditions or DNS configuration changes.
- Disappeared hosts are identified based on DNS resolution results, not proof that the underlying infrastructure has been decommissioned.
- HTTP/HTTPS probing generates network traffic to discovered endpoints.
- Ensure that all probing activities comply with applicable policies, agreements, and laws.

## Limitations

- Subdomain discovery depends on the data sources available to Subfinder.
- Wildcard DNS detection may not eliminate every false positive.
- Only A and AAAA DNS records are queried.
- HTTP/HTTPS probing is limited to hosts with successful DNS resolution.
- Snapshot comparison tracks DNS-resolved hostnames, not IP address changes or historical HTTP service changes.
- A failed or incomplete scan should not be treated as an authoritative infrastructure change.

## License

Specify your preferred license before distributing this project.

## Disclaimer

DeadShot is provided for educational purposes, authorized security assessments, and internal domain intelligence operations.

The author assumes no responsibility for misuse or unauthorized activity performed using this tool.

**Use DeadShot responsibly and only against domains for which you have explicit authorization.**
