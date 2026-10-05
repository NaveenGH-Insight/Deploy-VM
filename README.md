# Windows 11 + SQL Server Express 2022 on Azure

Terraform and CI/CD starter project for a **private Windows 11 dev/test VM** running SQL Server Express 2022 in the existing `GenAI-Test` resource group.

| Setting | Default |
| --- | --- |
| Subscription | `3e3f5f63-438b-4205-b50e-df27fa676994` |
| Resource group | `GenAI-Test` (must already exist) |
| Region | Inherited from `GenAI-Test` |
| VM | `genai-sql-win11-vm`, `Standard_D2s_v5` |
| Windows image | Microsoft Windows 11 Enterprise Marketplace image; SKU is configurable |
| VNet / subnet | `10.50.0.0/16` / `10.50.1.0/24` |
| SQL instance | `SQLEXPRESS`, TCP port `1433`, Windows authentication |

This project creates only its VM, managed OS disk, NIC, dedicated VNet/subnet, NSG, NAT Gateway and public egress IP, plus the VM run-command operation. It does **not** create, import, or manage the resource group or the existing Cognitive Services resources. There is no public IP on the VM and no public inbound RDP or SQL rule. Private-network sources can connect on RDP/3389 and SQL/1433.

## Important before deployment

- This Windows 11 client image is intended for Visual Studio subscription **development/test** use. Confirm the subscription has the applicable Windows client image entitlement before deploying; this project does not grant production Windows virtualization rights.
- The image SKU varies by release and subscription access. The default `win11-25h2-ent` is a starting point, not a verified entitlement for every subscription. The pipeline checks that the selected East US image is visible before Terraform runs. If it fails, list available SKUs with `az vm image list-skus --location eastus --publisher MicrosoftWindowsDesktop --offer Windows-11 --output table` and set `WINDOWS_IMAGE_SKU` (GitHub Actions) or `WINDOWS_IMAGE_SKU` (Azure DevOps) to an available SKU.
- The first deployment downloads roughly 280 MB of SQL media onto the VM. A NAT Gateway and static public IP are included for explicit outbound access, required for SQL media download and Windows updates on the private subnet. They add ongoing hourly and data-processing costs beyond the VM and disk; check current regional pricing before applying.
- `Standard_D2s_v5` is a modest dev/test size. Resize it for larger databases or concurrent workloads.
- Terraform state contains the VM administrator password and other sensitive values. Use the private Azure Blob backend below; do not commit state files, plans, credentials, or `.tfvars`.
- SQL Server Express is installed with Windows authentication only; the setup does not enable SQL authentication or install SSMS. Connect to `tcp:<private-ip>,1433` from a host routed to the VNet. Azure Bastion can provide RDP access, but SQL client traffic needs a VPN or another private route. If the VPN client pool is outside the VNet address range, set `vpn_client_address_prefixes` in Terraform so Windows Defender Firewall permits that client range.

## One-time Azure setup

### 1. Create the remote Terraform state storage

Install Azure CLI, sign in interactively, then from this repository run:

```powershell
az login
.\scripts\bootstrap-state.ps1 -StorageAccountName <globally-unique-lowercase-name>
```

The script uses the existing `GenAI-Test` group and creates a private `tfstate` blob container in a StorageV2 account with HTTPS-only, TLS 1.2+, and shared-key/blob-public access disabled. The account's public endpoint is reachable by hosted CI agents, but data access requires Azure AD authorization. Keep the state account and container; CI will use them for locking and state.

Container creation uses your signed-in Azure AD identity. If it fails with an authorization error, grant your operator identity `Storage Blob Data Contributor` on the new storage account, wait for role propagation, then rerun the script:

```powershell
$storageAccountId = az storage account show --name <storage-account-name> --resource-group GenAI-Test --query id --output tsv
$operatorObjectId = az ad signed-in-user show --query id --output tsv
az role assignment create --assignee-object-id $operatorObjectId --assignee-principal-type User --role "Storage Blob Data Contributor" --scope $storageAccountId
```

This role assignment requires Owner or User Access Administrator permission at that scope. If you lack it, ask an administrator to create the container or grant the role. The pipeline identity still needs its own Blob data role below.

### 2. Configure workload identity federation

Create an Entra application/service principal for the deployment identity and configure a federated credential:

- **GitHub Actions:** issuer `https://token.actions.githubusercontent.com`, subject `repo:<OWNER>/<REPO>:environment:production`, audience `api://AzureADTokenExchange`. Create a GitHub environment named `production` and add required reviewers if you want an approval gate.
- **Azure DevOps:** create an Azure Resource Manager service connection using workload identity federation. Protect the `GenAI-Test-Production` environment with approvals/checks before enabling the deployment stage.

Give the deployment service principal the following roles:

```powershell
$subscription = "3e3f5f63-438b-4205-b50e-df27fa676994"
$principalObjectId = "<service-principal-object-id>"
$resourceGroupScope = "/subscriptions/$subscription/resourceGroups/GenAI-Test"
$storageAccountId = az storage account show --name <storage-account-name> --resource-group GenAI-Test --query id --output tsv

az role assignment create --assignee-object-id $principalObjectId --assignee-principal-type ServicePrincipal --role Reader --scope $resourceGroupScope
az role assignment create --assignee-object-id $principalObjectId --assignee-principal-type ServicePrincipal --role "Virtual Machine Contributor" --scope $resourceGroupScope
az role assignment create --assignee-object-id $principalObjectId --assignee-principal-type ServicePrincipal --role "Network Contributor" --scope $resourceGroupScope
az role assignment create --assignee-object-id $principalObjectId --assignee-principal-type ServicePrincipal --role "Storage Blob Data Contributor" --scope $storageAccountId
```

The first three roles are scoped to the existing resource group because Terraform creates VM and networking resources there. This permits management of other resources in that group; use a custom role or narrower scopes if that is too broad. The Blob data role is scoped to the state storage account. The identity needs permission to create role assignments only if you choose to assign these roles yourself; Terraform does not create role assignments.

### 3. Set pipeline variables and secrets

Use one pipeline system per deployment at a time; both share the same Terraform state.

**GitHub Actions** (`Settings` → `Secrets and variables`):

- Repository/environment secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `VM_ADMIN_PASSWORD`.
- Repository/environment variables: `TF_STATE_RESOURCE_GROUP` (`GenAI-Test`), `TF_STATE_STORAGE_ACCOUNT`, `TF_STATE_CONTAINER` (`tfstate`), `TF_STATE_KEY` (`genai-test-sql-vm.tfstate`).
- Optional variable: `WINDOWS_IMAGE_SKU` if the default image is not available.
- Add required reviewers to the `production` environment to gate deployment. PRs only run formatting and validation; pushes to `main` and manual workflow dispatch can deploy.

**Azure DevOps**:

- Create pipeline variables `AZURE_SERVICE_CONNECTION`, `AZURE_SUBSCRIPTION_ID`, `TF_STATE_RESOURCE_GROUP`, `TF_STATE_STORAGE_ACCOUNT`, `TF_STATE_CONTAINER`, `TF_STATE_KEY`, and `VM_ADMIN_PASSWORD`. Mark `VM_ADMIN_PASSWORD` secret.
- Optional variable `WINDOWS_IMAGE_SKU` if the default image is not available.
- Create/protect the `GenAI-Test-Production` environment with the desired approval checks. The YAML runs format/validation on PRs and plans/applies after a non-PR run passes validation.

Set the admin password as a secure secret/variable, not in source control. It must contain at least 14 characters including uppercase, lowercase, a digit and a special character.

## Deploy

Push the repository to GitHub and use Actions, or import it into Azure DevOps and run `azure-pipelines.yml`. Before the first CI run, complete the state and identity setup above. The deployment pipeline:

1. Runs `terraform fmt -check` and `terraform validate`.
2. Authenticates without a client secret (OIDC for GitHub; federated Azure service connection for Azure DevOps).
3. Checks the selected Windows 11 image in East US.
4. Initializes the private remote backend, creates a saved plan, and applies that exact plan.

To validate locally without Azure or a remote backend:

```powershell
cd infra
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

`terraform validate` checks configuration/provider schema; it does not verify subscription Marketplace eligibility, policy compliance, quota, or deployment success. Do not run `terraform apply` locally unless you intentionally want to deploy.

## Connect and verify

After a successful apply, read the Terraform outputs for the VM private IP and SQL instance. From a machine with private network connectivity:

- RDP to the private IP on port 3389.
- Connect with a SQL client to `tcp:<private-ip>,1433`, instance `SQLEXPRESS`, using Windows authentication.
- The VM's NAT public IP is **egress only** and must not be used for RDP or SQL connections.

The SQL installation runs as an Azure VM Run Command after provisioning. A non-successful media download, signature check, extraction, or SQL setup exit code causes Terraform apply to fail rather than reporting a successful install.

## Tear down

`terraform destroy` removes only resources tracked in this project's state, not the resource group or unrelated resources. The state storage account is deliberately not managed by this Terraform configuration; delete it separately only after you are certain the state is no longer needed.
