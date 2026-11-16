# Cloud Security: Azure + ScoutSuite

Intentionally insecure Azure lab, scanned with ScoutSuite. Three findings (Identity, Data, Network) are analysed for exploitability and blast radius, then prioritised.

| Deliverable | File |
|---|---|
| Architecture diagram | [diagram/architecture.png](diagram/architecture.png) ([SVG](diagram/architecture.svg)) |
| Mini report (prioritisation + remediation) | [report/Azure_Cloud_Security_Report.pdf](report/Azure_Cloud_Security_Report.pdf) |
| Insecure infrastructure | [terraform/](terraform/) |
| ScoutSuite runner + findings extractor | [scoutsuite/](scoutsuite/) |

## Run it (Azure Cloud Shell, Bash)

```bash
git clone <this repo> && cd AfricaHackon/Cloud-Security/terraform
terraform init
terraform apply -var location=southafricanorth   # Entra ID user + Sub + RG + VNet + Subnet + NSG + VM + Storage
terraform output                                 # note the public_blob_url and vm_public_ip

# Prove the data exposure (F2)
curl "$(terraform output -raw public_blob_url)"

# Deploy + run ScoutSuite
cd ../scoutsuite && ./run_scoutsuite.sh
python3 extract_findings.py ~/scoutsuite-report
```

Take screenshots of the ScoutSuite dashboard and the RBAC, Storage and NSG findings, then drop them into the `[ Insert screenshot ]` boxes in `report/Azure_Cloud_Security_Report.html` and re-print it to PDF.

## Findings

| Priority | Finding | One-line remediation |
|---|---|---|
| P1 | **Data:** container `customer-exports` allows anonymous access, HTTPS not required | Disable anonymous blob access and require HTTPS, then restrict the network to a private endpoint. |
| P2 | **Network:** NSG allows SSH/RDP from `*` to a VM with password auth and a Contributor managed identity | Delete the 0.0.0.0/0 22/3389 rules, use Bastion/JIT and SSH keys, and reduce the VM identity's role. |
| P3 | **Identity:** custom role with `Actions=["*"]` at subscription scope assigned to a standard user with no MFA | Replace the wildcard custom role with a resource-group-scoped built-in role and enforce MFA. |

## Clean up

```bash
cd terraform && terraform destroy
```

> The prerequisite: the account running `terraform apply` must be able to create Entra ID users (User Administrator) and role definitions (Owner / User Access Administrator) on the subscription.
