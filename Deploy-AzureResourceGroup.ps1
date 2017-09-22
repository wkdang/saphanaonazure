#,Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage
[cmdletbinding()]
Param(
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $ArtifactsLocationSasTokenName,
    [string] $DSCSourceFolder = 'DSC',
    #Removing Both Inputs as the DSC Config is built from the VMSize and the VMSize is specified in the Parameters
    #[string] $DscConfigName = 'SAPConfiguration',
    #[string] [ValidateSet("Standard_GS5","Standard_M64s","Standard_M64ms","Standard_M128ms","Standard_M128s","Standard_E64S_V3")] $vmSize = "Standard_GS5",
    [switch] $ValidateOnly,
    [switch] $deploytoexistingvnet,
    [string] $vnetname



)

try {
    [Microsoft.Azure.Common.Authentication.AzureSession]::ClientFactory.AddUserAgent("VSAzureTools-$UI$($host.name)".replace(' ','_'), '3.0.0')
} catch { }

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3

function Format-ValidationOutput {
    param ($ValidationOutput, [int] $Depth = 0)
    Set-StrictMode -Off
    return @($ValidationOutput | `
        Where-Object { $_ -ne $null } | `
        ForEach-Object { @('  ' * $Depth + ': ' + $_.Message) + @(Format-ValidationOutput @($_.Details) ($Depth + 1)) })
}

$OptionalParameters = New-Object -TypeName Hashtable
$TemplateFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateFile))
$TemplateParametersFile = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $TemplateParametersFile))
$JsonParameters = (Get-Content $TemplateParametersFile) -join "`n" | ConvertFrom-Json
$ResourceGroupLocation = $JsonParameters.parameters.ResourceGroupLocation.value
$ResourceGroup_Name = $JsonParameters.parameters.ResourceGroup_Name.value

if((Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -eq $ResourceGroup_Name}) -eq $null )
{
    # Create or update the resource group using the specified template file and template parameters file
    New-AzureRmResourceGroup -Name $ResourceGroup_Name `
                                -Location $ResourceGroupLocation `
                                -Verbose -Force
    $message = ('The Resource Group ' + $ResourceGroup_Name + ' was created.')
    Write-Host $message
}
$DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))


#Enumerate Existing Network (We are choosing to default to the primary subnet for deployment)
if($deploytoexistingvnet)
{
    write-host "Gathering Existing VNet Information"
    $vnet = Get-AzureRMVirtualNetwork -ResourceGroupName $ResourceGroup_Name -Name $vnetname
    $vnetprefix = $vnet.addressspace.addressprefixes[0]
    $subnetname = $vnet.Subnets[0].Name
    $subnetprefix = $vnet.Subnets[0].AddressPrefix
}

# This section allows for the running the script without uploading the files again. It assumes that you have already uploaded the files with the default values
if(!$UploadArtifacts){
    
    $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    $StorageContainerName = $ResourceGroup_Name.ToLowerInvariant() + '-stageartifacts'
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})
    $StorageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context

    #$mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force

    $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  .\preReqInstall.sh -Force
    $SapBitsUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName + '/SapBits')
    $baseUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName)
}

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))


    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present

    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        (Get-Content $TemplateParametersFile) -join "`n" | ConvertFrom-Json
    }
    $ArtifactsLocationName = '_artifactsLocation'
    $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    $StorageContainerName = $ResourceGroup_Name.ToLowerInvariant() + '-stageartifacts'

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
        $message = ('Staging storage account ' + $StorageAccountName + ' was created.')
        Write-Host $message
    }

    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {

        # Create ContinerUri
        $SapBitsUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName + '/SapBits')

        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | `
            ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            # Publish-AzureRmVMDscConfiguration $DSCSourceFilePath `
            #     -OutputArchivePath $DSCArchiveFilePath `
            #     -Force -Verbose
        }
    }

    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})

    # Create the storage account if it doesn't already exist
    if ($StorageAccount -eq $null) {
        $StorageResourceGroupName = 'ARM_Deploy_Staging'
        New-AzureRmResourceGroup -Location "$ResourceGroupLocation" `
                                    -Name $StorageResourceGroupName `
                                    -Force
        $StorageAccount = New-AzureRmStorageAccount -StorageAccountName $StorageAccountName `
                                                    -Type 'Standard_LRS' `
                                                    -ResourceGroupName $StorageResourceGroupName `
                                                    -Location "$ResourceGroupLocation"
        $message = ($StorageAccountName + ' was created to deploy staging resources.')
        Write-Host $message
    }

    # Copy files from the local storage staging location to the storage account container
    New-AzureStorageContainer -Name $StorageContainerName `
                                -Context $StorageAccount.Context `
                                -Permission Container `
                                -ErrorAction SilentlyContinue *>&1

    $ArtifactFilePaths = Get-ChildItem $ArtifactStagingDirectory -Recurse -File | ForEach-Object -Process {$_.FullName}
    foreach ($SourcePath in $ArtifactFilePaths) {
        Set-AzureStorageBlobContent -File $SourcePath -Blob $SourcePath.Substring($ArtifactStagingDirectory.length + 1) `
            -Container $StorageContainerName `
            -Context $StorageAccount.Context `
            -Force
    }
    $message = 'Staging files have been uploaded.'
    Write-Host $message

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
            (New-AzureStorageContainerSASToken -Container $StorageContainerName `
                                                -Context $StorageAccount.Context `
                                                -Permission r `
                                                -ExpiryTime (Get-Date).AddHours(4))
    }

    # Set DSC File Uris
    if (Test-Path $DSCSourceFolder) {
        $StorageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context
        # $mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force
        $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  '.\preReqInstall.sh' -Force
    }
}


$vmName = $JsonParameters.parameters.vmName.value
$compjobguid = [GUID]::NewGUID()
$ConfigName = ($JsonParameters.parameters.vmSize.value)

if ($ValidateOnly) {
    $ErrorMessages = Format-ValidationOutput (Test-AzureRmResourceGroupDeployment -ResourceGroupName $ResourceGroup_Name `
                                                                -TemplateFile $TemplateFile `
                                                                -TemplateParameterFile $TemplateParametersFile)
    if ($ErrorMessages) {
        Write-Output '', 'Validation returned the following errors:', @($ErrorMessages), '', 'Template is invalid.'
    }
    else {
        Write-Output '', 'Template is valid.'
    }
}
else {
   

    # Deploy the SAP HANA Environment from the ARM Template
    if(!$deploytoexistingvnet)
    {
        write-host "Deploying SAP HANA to New VNET" -foreground Green -Background Black
        New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       -ResourceGroupName $ResourceGroup_Name `
                                       -customUri $customScriptExtUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
                                       -baseUri $baseUri `
                                       -DscConfigName $ConfigName `
                                       -CompJobGuid $compjobguid `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages

    }
    else
    {
        write-host "Deploying to Existing VNET" -foreground Green -Background Black
        
        New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
        -TemplateFile $TemplateFile `
        -TemplateParameterFile $TemplateParametersFile `
        -ResourceGroupName $ResourceGroup_Name `
        -customUri $customScriptExtUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
        -baseUri $baseUri `
        -DscConfigName $ConfigName `
        -CompJobGuid $compjobguid `
        -deploytoexistingvnet "true" `
        -NetworkName $vnetname `
        -addressPrefixes $vnetprefix `
        -subnetName $subnetname `
        -subnetPrefix $subnetprefix `
        -Force -Verbose `
        -ErrorVariable ErrorMessages
    }


# Check Node DSC compliance status
Write-host "Assigning SAP Hana to DSC Node"
$AutomationAccount = Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup_Name -Name $vmName
$Node = $AutomationAccount | Get-AzureRmAutomationDscNode
$message = ('The DSC Node: ' + $Node.Name + ' is ' + $Node.Status)
while ($Node.Status -eq 'Pending') {
    $Node = $Node | Get-AzureRmAutomationDscNode
    Write-Host $message
    Start-Sleep -Seconds 3
}


    # Install HANA Monitoring Extension

 Set-AzureRmVMAEMExtension -ResourceGroupName $ResourceGroup_Name -VMName $vmName


if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}
