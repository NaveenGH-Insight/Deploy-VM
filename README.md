# Reusable Windows 11 + SQL Server Express Azure deployment

Terraform provisions an existing-resource-group deployment of a private Windows 11 VM and installs SQL Server Express 2022. Use the same Terraform configuration from GitHub Actions or Azure DevOps by supplying each target environment's values through protected environment variables and secrets.

This repository contains **no subscription IDs, resource-group names, passwords, state-account names, network CIDRs, VM sizes, or Marketplace image SKU/version defaults**. Set them in the CI environment. The only location is discovered from the configured existing resource group, so the VM, networking and image availability check use that resource group's region.

## What Terraform creates

- One Windows 11 VM, managed OS disk, and NIC in the existing resource group.
- A dedicated VNet and subnet, NSG rules allowing RDP/3389 and SQL/1433 only from the Azure `VirtualNetwork` service tag, and a deny rule for other inbound traffic.
- A NAT Gateway and static public IP for outbound downloads and updates. The VM itself has no public IP; inbound RDP and SQL are not exposed to the internet.
- An Azure VM Run Command that verifies Microsoft's SQL media signature, installs SQL Server Express 2022, enables TCP, sets the configured port, and opens the guest firewall only for the private VNet/VPN address ranges.

SQL Express uses Windows authentication and a fixed `SQLEXPRESS` instance. SSMS is not installed. Connect from a machine with a private route to the VNet. Windows client images are suitable only when the subscription has the appropriate dev/test entitlement; verify licensing and Marketplace access for each target subscription.

SQL Server Express has edition limits, including a maximum 10 GB size per relational database. Use a different SQL Server edition if a workload outgrows Express.

NAT Gateway, public IP, VM compute and storage incur ongoing charges. Review regional pricing and configure cost controls before enabling deployment. Terraform state contains the VM administrator password; always use a private remote backend and protect access to it.

## Required configuration

Use one independent remote-state key per environment. Do not share a state key between environments or between this configuration and unrelated Terraform deployments.

### Terraform input variables

| Input | Required | Description |
|---|---:|---|
| `subscription_id` | Yes | Target Azure subscription ID. |
| `resource_group_name` | Yes | Existing resource group. Terraform does not create or delete it. |
| `vm_name` | Yes | Alphanumeric/hyphen base name for this deployment's VM and related resources. |
| `vm_size` | Yes | Azure VM size available in the target region/subscription. |
| `os_disk_storage_account_type` | Yes | Managed OS disk SKU supported in the target environment. |
| `os_disk_size_gb` | Yes | OS disk capacity in GiB, compatible with the selected image. |
| `admin_username` | Yes | Local Windows administrator username. |
| `admin_password` | Yes | Secret with at least 14 characters, upper/lowercase, digit and special character. |
| `windows_image_sku` | Yes | Windows 11 Marketplace SKU visible and licensed for this subscription. |
| `windows_image_version` | Yes | Available image version; use a specific version for repeatable builds or `latest` to follow the current image. |
| `vnet_address_space` | Yes | JSON list of non-overlapping CIDRs, e.g. `["10.80.0.0/16"]`. |
| `subnet_address_prefix` | Yes | Subnet CIDR contained by the VNet, e.g. `10.80.1.0/24`. |
| `vpn_client_address_prefixes` | Yes | JSON CIDR list allowed by Windows Firewall; use `[]` when not using VPN clients. |
| `tags` | Yes | JSON object of resource tags; use `{}` if no tags are required. |
| `sql_tcp_port` | Yes | SQL TCP port, typically `1433`. |

Marketplace publisher/offer and SQL Server Express installer URL identify the requested products. The deployment preflight checks the selected SKU/version in the resource group's region before running Terraform.

Find current image values for a target subscription/region after authenticating the Azure CLI:

```bash
az vm image list-skus --location <resource-group-region> --publisher MicrosoftWindowsDesktop --offer Windows-11 --output table
az vm image list --location <resource-group-region> --publisher MicrosoftWindowsDesktop --offer Windows-11 --sku <selected-sku> --all --output table
```

Use a SKU and version that your target subscription is entitled to deploy.

### Remote Terraform state

Create an Azure StorageV2 account and private blob container before CI deployment. The storage account can be in a separate state resource group, but the backend identity needs data-plane access to it. The state account is deliberately separate from the Terraform-managed application resources.

The helper script creates the storage account/container only when absent and refuses to modify an existing account whose HTTPS/TLS/shared-key/public-blob settings do not match its required security settings:

```powershell
az login
.\scripts\bootstrap-state.ps1 `
  -SubscriptionId <subscription-id> `
  -ResourceGroupName <existing-state-resource-group> `
  -Location <state-region> `
  -StorageAccountName <globally-unique-lowercase-name> `
  -ContainerName <private-container-name> `
  -PublicNetworkAccess <Enabled-or-Disabled>
```

The signed-in operator needs permission to create a storage account in that resource group and `Storage Blob Data Contributor` on the state account to create the container using Azure AD. Choose `Enabled` only when the CI runner is allowed to reach the public storage endpoint; data-plane access still requires Azure AD. For `Disabled`, use a self-hosted CI runner with private connectivity to the storage endpoint. The script does not change existing account settings.

Set these state-backend variables in the CI environment:

| Name | Meaning |
|---|---|
| `TF_STATE_RESOURCE_GROUP` | Resource group containing the state account. |
| `TF_STATE_STORAGE_ACCOUNT` | Storage account name. |
| `TF_STATE_CONTAINER` | Private blob container. |
| `TF_STATE_KEY` | Unique state blob key for this environment. |

## GitHub Actions

1. Add `.github/workflows/terraform.yml` to the GitHub repository's default branch.
2. Create a GitHub Environment for each deployment target (for example, a development or production environment). Add required reviewers/branch restrictions for environments that need approval.
3. Configure an Entra federated credential for each GitHub Environment used for deployment:
   - Issuer: `https://token.actions.githubusercontent.com`
   - Subject: `repo:<OWNER>/<REPOSITORY>:environment:<GITHUB_ENVIRONMENT>`
   - Audience: `api://AzureADTokenExchange`
4. Add the following **Environment secrets**:
   - `AZURE_CLIENT_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_SUBSCRIPTION_ID`
   - `TF_VAR_ADMIN_PASSWORD`
5. Add the following **Environment variables**:
   - `TF_VAR_RESOURCE_GROUP_NAME`
   - `TF_VAR_VM_NAME`
   - `TF_VAR_VM_SIZE`
   - `TF_VAR_OS_DISK_STORAGE_ACCOUNT_TYPE`
   - `TF_VAR_OS_DISK_SIZE_GB`
   - `TF_VAR_ADMIN_USERNAME`
   - `TF_VAR_WINDOWS_IMAGE_SKU`
   - `TF_VAR_WINDOWS_IMAGE_VERSION`
   - `TF_VAR_VNET_ADDRESS_SPACE`
   - `TF_VAR_SUBNET_ADDRESS_PREFIX`
   - `TF_VAR_VPN_CLIENT_ADDRESS_PREFIXES` (use `[]` if unused)
   - `TF_VAR_TAGS` (use `{}` if unused)
   - `TF_VAR_SQL_TCP_PORT`
   - `TF_STATE_RESOURCE_GROUP`
   - `TF_STATE_STORAGE_ACCOUNT`
   - `TF_STATE_CONTAINER`
   - `TF_STATE_KEY`

On pull requests, the workflow only runs Terraform formatting and validation. To deploy, use **Actions → Terraform → Run workflow** on the `main` branch, select the GitHub Environment, and explicitly set `deploy` to `true`. The environment's protection rules gate the job. The workflow checks the target resource group/image, initializes Azure Blob state, creates a saved Terraform plan, and applies that plan. The workflow has no push-to-deploy trigger.

The deployment identity needs permission to read the target resource group, create/manage the VM and network resources, and execute the VM Run Command. A typical built-in-role starting point is `Reader`, `Virtual Machine Contributor`, and `Network Contributor` scoped to the target resource group, plus `Storage Blob Data Contributor` scoped to the state storage account. Confirm the exact operations against organization policy and provider behavior; prefer narrower custom role scopes when practical. Do not grant subscription-wide `Owner` solely for convenience.

## Azure DevOps

1. Import the repository and select `azure-pipelines.yml`.
2. Install the **Terraform Installer** task extension if it is not already available to the organization.
3. Create an Azure Resource Manager service connection using **workload identity federation**, targeting the desired subscription. Do not store a client secret in pipeline YAML.
4. Create a pipeline variable group for the target environment and authorize this pipeline to use it. Set the same Terraform/backend variables listed above, plus `AZURE_SERVICE_CONNECTION` containing the service-connection name. Mark `TF_VAR_admin_password` secret.
5. Create an Azure DevOps environment for this target and configure its approval/checks before allowing deployment.
6. Queue the pipeline and select the matching variable group and protected environment. Enable **Deploy after validation** only when ready to deploy; its default is false. Pull requests and normal CI runs validate only.

The variable group must also define `TF_VAR_VPN_CLIENT_ADDRESS_PREFIXES` as JSON, `TF_VAR_TAGS` as JSON, and `TF_VAR_SQL_TCP_PORT`. Use `[]` and `{}` for the first two if unused. The service connection identity needs the same target-resource-group and state-storage roles described for GitHub Actions. Keep one variable group and state key per environment.

## Local validation (no deployment)

Install Terraform and run:

```powershell
Set-Location infra
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

These checks do not contact or modify Azure. A successful `terraform validate` does not prove that the selected image SKU/license, regional quota, policy, or runtime installation is available in a target subscription. The CI deployment preflight checks the image, but a Terraform plan/apply is still required to verify deployment-time constraints.

## Outputs and cleanup

Terraform outputs the VM ID, private IP, SQL endpoint name, and egress-only NAT IP. Use a VPN/private route or a separately managed private access solution to connect; never add public inbound RDP/SQL for convenience.

`terraform destroy` deletes resources in this Terraform state. It does not delete the existing resource group or the separately managed state account. Review the plan carefully before any destroy operation.
