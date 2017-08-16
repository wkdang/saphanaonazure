#Requires -Version 3.0
#Requires -Module AzureRM.Resources
#Requires -Module Azure.Storage
#Requires -Module nx

Param(
    [switch] $UploadArtifacts,
    [string] $StorageAccountName,
    [string] $TemplateFile = 'azuredeploy.json',
    [string] $TemplateParametersFile = 'azuredeploy.parameters.json',
    [string] $ArtifactStagingDirectory = '.',
    [string] $ArtifactsLocationSasTokenName,
    [string] $DSCSourceFolder = 'DSC',
    [switch] $ValidateOnly,
    [switch] $SkipUpload
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

# This section allows for the running the script without uploading the files again. It assumes that you have already uploaded the files with the default values
if ($SkipUpload){
    $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    $StorageContainerName = $ResourceGroup_Name.ToLowerInvariant() + '-stageartifacts'
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})
    $StorageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context
    $mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force
    $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  .\preReqInstall.sh -Force
}

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

    # Parse the parameter file and update the values of artifacts location and artifacts location SAS token if they are present

    if (($JsonParameters | Get-Member -Type NoteProperty 'parameters') -ne $null) {
        $JsonParameters = $JsonParameters.parameters
    }
    $ArtifactsLocationName = '_artifactsLocation'
    $ArtifactsLocationSasTokenName = '_artifactsLocationSasToken'
    $StorageContainerName = $ResourceGroup_Name.ToLowerInvariant() + '-stageartifacts'


    # Create DSC configuration archive
    if (Test-Path $DSCSourceFolder) {

        # Create MOF file and change file encoding
        function CreateMof {
            Set-Location $DSCSourceFolder
            . .\ExampleConfiguration.ps1
            Set-Location ..
            $mofFile = Get-ChildItem ($DSCSourceFolder +'\sap-hana.mof')
            $mofFileContent = Get-Content $mofFile
            $mofOutFile = ($DSCSourceFolder +'sap-hana-out.mof')
            [IO.File]::WriteAllLines($mofOutFile,$mofFileContent)
            Move-Item $mofOutFile $mofFile -Force
        }
        CreateMof

        $DSCSourceFilePaths = @(Get-ChildItem $DSCSourceFolder -File -Filter '*.ps1' | `
            ForEach-Object -Process {$_.FullName})
        foreach ($DSCSourceFilePath in $DSCSourceFilePaths) {
            $DSCArchiveFilePath = $DSCSourceFilePath.Substring(0, $DSCSourceFilePath.Length - 4) + '.zip'
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath `
                -OutputArchivePath $DSCArchiveFilePath `
                -Force -Verbose
        }
    }

    # Create a storage account name if none was provided
    if ($StorageAccountName -eq '') {
        $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
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

    # Generate a 4 hour SAS token for the artifacts location if one was not provided in the parameters file
    if ($OptionalParameters[$ArtifactsLocationSasTokenName] -eq $null) {
        $OptionalParameters[$ArtifactsLocationSasTokenName] = ConvertTo-SecureString -AsPlainText -Force `
            (New-AzureStorageContainerSASToken -Container $StorageContainerName `
                                                -Context $StorageAccount.Context `
                                                -Permission r `
                                                -ExpiryTime (Get-Date).AddHours(4))
    }

    # Set DSC File Uri
    if (Test-Path $DSCSourceFolder) {
        $StorageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context
        $mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force
        $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  .\preReqInstall.sh -Force
    }
}

# Create or update the resource group using the specified template file and template parameters file
New-AzureRmResourceGroup -Name $ResourceGroup_Name -Location $ResourceGroupLocation -Verbose -Force

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
    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       -ResourceGroupName $ResourceGroup_Name `
                                       -fileUri $mofUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
                                       -customUri $customScriptExtUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages
    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}