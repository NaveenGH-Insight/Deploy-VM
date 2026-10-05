# Azure Deployment Plan

> **Status:** Planning — user approved the deployment scope; pre-deployment checks are blocked pending Azure CLI sign-in.

Generated: 2026-10-06

## 1. Project Overview

**Goal:** Deploy the prepared private Windows 11 dev/test VM and install SQL Server Express 2022 in the existing resource group.

**Path:** Deploy existing Terraform project.

**Workspace:** `C:\Users\nnannuta\.copilot\chats\2026-10-05\improved-umbrella-effd9f8a\genai-test-sql-vm`

## 2. Requirements and Azure Context

| Attribute | Value |
|-----------|-------|
| Classification | Development/test (not production) |
| Scale | Small, single VM |
| Budget | No fixed cap specified; VM, disk, NAT Gateway, public egress IP, and traffic are billable |
| Subscription | Visual Studio Subscription-AMAN (`3e3f5f63-438b-4205-b50e-df27fa676994`) — user-confirmed |
| Location | East US (`eastus`) — existing resource group location and user-confirmed |
| Resource group | Existing `GenAI-Test` |

The user approved deployment of the complete project stack into this subscription/resource group. Do not change or import the existing Cognitive Services account or project.

## 3. Existing Resources and Policy Constraints

The resource group currently contains `Smartaibynvn` and its `smartai` project, both in East US.

Subscription policy lookup found two management-group assignments: the tenant-root CSPM initiative and Activity Log streaming for Administrative/Security categories. The returned assignment summaries did not expose individual policy rules or effects; no deployment-specific denial was identified from the summaries.

## 4. Recipe Selection

**Selected:** Existing pure Terraform project.

**Rationale:** The user requested Terraform and a direct deployment now; the repository already contains Terraform configuration plus GitHub Actions and Azure DevOps pipelines. This deployment uses Terraform directly, not CI/CD.

## 5. Architecture

**Stack:** Single private Windows VM with outbound NAT and SQL Express installed through VM Run Command.

| Resource | Quantity | Configuration / purpose |
|----------|----------|-------------------------|
| `Microsoft.Compute/virtualMachines` | 1 | Windows 11 Enterprise Marketplace image; `Standard_D2s_v5`; dev/test |
| Managed OS disk | 1 | 128 GiB Standard SSD |
| `Microsoft.Network/virtualNetworks` | 1 | Dedicated VNet, `10.50.0.0/16` |
| `Microsoft.Network/virtualNetworks/subnets` | 1 | Private subnet, `10.50.1.0/24` |
| `Microsoft.Network/networkInterfaces` | 1 | Private VM NIC |
| `Microsoft.Network/networkSecurityGroups` | 1 | RDP/3389 and SQL/1433 from `VirtualNetwork`; deny other inbound |
| `Microsoft.Network/natGateways` | 1 | Explicit outbound access for VM downloads and updates |
| `Microsoft.Network/publicIPAddresses` | 1 | Standard static egress-only IP for NAT Gateway |
| `Microsoft.Compute/virtualMachines/runCommands` | 1 | Download and install SQL Server Express 2022; configure TCP/1433 |

The VM has no public IP. SQL and RDP are not exposed to the public internet. The NAT Gateway and public IP incur ongoing charges.

## 6. Provisioning Limit Checklist

| Resource type / quota | Deploy | Current usage / limit | Capacity status / source |
|-----------------------|--------|-----------------------|--------------------------|
| `Microsoft.Compute/virtualMachines`, `Standard_D2s_v5` (regional vCPU-family quota and VM quota) | 1 VM / 2 vCPUs | Not yet retrieved | Blocked: local Azure CLI reports not signed in; `az quota list` and usage cannot be checked |
| `Microsoft.Network/publicIPAddresses` (Standard IPv4) | 1 | Not yet retrieved | Blocked: local Azure CLI reports not signed in; `az quota list` and usage cannot be checked |
| VNet, subnet, NIC, NSG, NAT Gateway and VM Run Command | 1 each | No subscription-specific limit data retrieved | Blocked: quota/availability preflight incomplete |

**Status:** Capacity is not yet verified. No Terraform plan or apply has been run. Do not proceed to deployment until preflight succeeds.

## 7. Execution Checklist

### Planning
- [x] Confirm requested full deployment scope, subscription, and location with user.
- [x] Inspect the existing resource group and avoid changes to unrelated resources.
- [x] Inspect policy assignment summaries.
- [ ] Check regional quotas and Windows image availability; local Azure CLI is not authenticated.
- [x] User approved the complete prepared stack.

### Execution and validation
- [ ] Complete Azure preflight checks after CLI sign-in.
- [ ] Validate this deployment plan using the `azure-validate` skill.
- [ ] Initialize a deployment state backend and supply the VM administrator password securely.
- [ ] Run Terraform plan and review all proposed changes.
- [ ] Apply only the approved plan using `azure-deploy`.
- [ ] Verify VM provisioning and SQL Server Express service/configuration.

## 8. Validation Proof

No deployment validation has been performed for this request. Existing local checks from repository preparation are not evidence of Azure subscription capacity, Marketplace eligibility, or deployed runtime health.
