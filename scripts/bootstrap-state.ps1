param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string] $StorageAccountName,

    [string] $SubscriptionId = '3e3f5f63-438b-4205-b50e-df27fa676994',
    [string] $ResourceGroupName = 'GenAI-Test',
    [string] $Location = 'eastus',
    [string] $ContainerName = 'tfstate'
)

$ErrorActionPreference = 'Stop'

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId. Run az login and verify access."
}

az storage account show --name $StorageAccountName --resource-group $ResourceGroupName --output none 2>$null
if ($LASTEXITCODE -ne 0) {
    az storage account create `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --location $Location `
        --sku Standard_LRS `
        --kind StorageV2 `
        --https-only true `
        --min-tls-version TLS1_2 `
        --allow-blob-public-access false `
        --allow-shared-key-access false `
        --public-network-access Enabled `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create state storage account $StorageAccountName."
    }
}

az storage container create `
    --account-name $StorageAccountName `
    --name $ContainerName `
    --auth-mode login `
    --public-access off `
    --output none
if ($LASTEXITCODE -ne 0) {
    throw "Unable to create or access state container $ContainerName."
}

Write-Output "Terraform backend ready: storage account '$StorageAccountName', container '$ContainerName'."
Write-Output "Assign the deployment identity 'Storage Blob Data Contributor' on the storage account before running CI."
