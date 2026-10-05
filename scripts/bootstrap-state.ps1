param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9]{3,24}$')]
    [string] $StorageAccountName,

    [Parameter(Mandatory = $true)]
    [string] $SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string] $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string] $Location,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[a-z0-9-]{3,63}$')]
    [string] $ContainerName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Enabled', 'Disabled')]
    [string] $PublicNetworkAccess
)

$ErrorActionPreference = 'Stop'

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId. Run az login and verify access."
}

az group show --name $ResourceGroupName --output none
if ($LASTEXITCODE -ne 0) {
    throw "Resource group '$ResourceGroupName' was not found in subscription '$SubscriptionId'."
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
        --public-network-access $PublicNetworkAccess `
        --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to create state storage account $StorageAccountName."
    }
} else {
    $storageSettings = az storage account show `
        --name $StorageAccountName `
        --resource-group $ResourceGroupName `
        --query "{httpsOnly:enableHttpsTrafficOnly,minimumTlsVersion:minimumTlsVersion,sharedKeyAccess:allowSharedKeyAccess,blobPublicAccess:allowBlobPublicAccess,publicNetworkAccess:publicNetworkAccess}" `
        --output json | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to inspect storage account security settings for $StorageAccountName."
    }
    if ($storageSettings.httpsOnly -ne $true -or
        $storageSettings.minimumTlsVersion -ne 'TLS1_2' -or
        $storageSettings.sharedKeyAccess -ne $false -or
        $storageSettings.blobPublicAccess -ne $false -or
        $storageSettings.publicNetworkAccess -ne $PublicNetworkAccess) {
        throw "Existing storage account '$StorageAccountName' does not meet the required HTTPS/TLS/shared-key/public-access settings. Review it before changing anything."
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

Write-Output "Terraform backend container '$ContainerName' is ready in storage account '$StorageAccountName'."
Write-Output "Grant the deployment identity 'Storage Blob Data Contributor' on the storage account before running CI."
