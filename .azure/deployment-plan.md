# Azure Deployment Plan

> **Status:** Reusable Terraform and CI/CD configuration only. No Azure deployment is requested or performed by this change.

## Goal

Maintain a reusable Terraform project to deploy a private Windows 11 VM and install SQL Server Express 2022 in a caller-selected existing resource group. All target-specific settings and credentials are supplied through Terraform inputs, CI environment variables, and protected secrets.

## Deployment architecture

Terraform creates a Windows VM, managed OS disk, private NIC, VNet/subnet, NSG, NAT Gateway, egress public IP, and VM Run Command for SQL Express installation. The resource-group location is discovered at deployment time. The subscription, existing resource group, VM size/name, image SKU/version, network prefixes, tags, credentials, and remote-state configuration are environment inputs.

GitHub Actions validates pull requests and supports explicitly dispatched deployments into a selected protected GitHub Environment. Azure Pipelines validates PR/CI runs and deploys only when the queue-time `deploy` parameter is enabled and the deployment environment approvals pass.

## Security and operational notes

- No inbound RDP or SQL access from the public internet; private networking is required for clients.
- OIDC/federated service connections are used rather than committed client secrets.
- Terraform state is remote and Azure AD protected; the admin password is sensitive and must be provided as a CI secret.
- NAT Gateway, public IP, VM compute and storage are billable.
- Marketplace access, Windows dev/test licensing, region quota, policy and image SKU availability must be checked for each target environment.

## Validation proof

Local Terraform format/validation, workflow YAML parsing and SQL installer syntax checks are run for repository changes. These do not deploy Azure resources or verify a target subscription's capacity, policy, image entitlement or live SQL installation.
