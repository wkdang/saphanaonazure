#,Requires -Version 3.0
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
    [string] $DscConfigName = 'ExampleConfiguration',
    [string] [ValidateSet("Standard_GS5","Standard_M64s","Standard_M64ms","Standard_M128ms","Standard_M128s")] $vmSize = "Standard_GS5",
    [switch] $ValidateOnly

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
#added in to support choosing multiple VM Sizes available for SAP Hana
if ($vmSize -eq $null)
{
    $vmSize = $JsonParameters.parameters.vmSize.value 
}
if((Get-AzureRmResourceGroup | Where-Object {$_.ResourceGroupName -eq $ResourceGroup_Name}) -eq $null )
{
    # Create or update the resource group using the specified template file and template parameters file
    New-AzureRmResourceGroup -Name $ResourceGroup_Name `
                                -Location $ResourceGroupLocation `
                                -Verbose -Force
    $message = ('The Resource Group ' + $ResourceGroup_Name + ' was created.')
    Write-Host $message
}

# This section allows for the running the script without uploading the files again. It assumes that you have already uploaded the files with the default values
if(!$UploadArtifacts){

    $StorageAccountName = 'stage' + ((Get-AzureRmContext).Subscription.Id).Replace('-', '').substring(0, 19)
    $StorageContainerName = $ResourceGroup_Name.ToLowerInvariant() + '-stageartifacts'
    $StorageAccount = (Get-AzureRmStorageAccount | Where-Object{$_.StorageAccountName -eq $StorageAccountName})
    $StorageContainer = Get-AzureStorageContainer -Name $StorageContainerName -Context $StorageAccount.Context
    $mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force
    $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  .\preReqInstall.sh -Force
    $SapBitsUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName + '/SapBits')
    $baseUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName)
}

if ($UploadArtifacts) {
    # Convert relative paths to absolute paths if needed
    $ArtifactStagingDirectory = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $ArtifactStagingDirectory))
    $DSCSourceFolder = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($PSScriptRoot, $DSCSourceFolder))

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
            Publish-AzureRmVMDscConfiguration $DSCSourceFilePath `
                -OutputArchivePath $DSCArchiveFilePath `
                -Force -Verbose
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
        #commenting out the upload of the mof file as we do direction compile in Azure
        #$mofUri = $StorageContainer | Set-AzureStorageBlobContent -File ($DSCSourceFolder + '.\sap-hana.mof') -Force
        $customScriptExtUri = $StorageContainer | Set-AzureStorageBlobContent -File  '.\preReqInstall.sh' -Force
    }
}

# Create an Azure Automation Account
$vmName = $JsonParameters.parameters.vmName.value
#$AutomationAccount = New-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup_Name `
#                                                    -Name $vmName `
#                                                    -Location $ResourceGroupLocation
#$AutomationAccountName = (Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup_Name -Name $vmName).AutomationAccountName
#$message = ($AutomationAccountName + ' has been created.')
#Write-Host $message

# Create Azure Automation Variable
#$baseUri = ('https://' + $StorageAccountName + '.blob.core.windows.net/' + $StorageContainerName)
#$AutomationVariable = $AutomationAccount | Get-AzureRmAutomationVariable
#if (($AutomationVariable | Where-Object {$_.Name -eq 'baseUri'}) -eq $null)
#{
#    $AutomationAccount | New-AzureRmAutomationVariable -Name 'baseUri' -Encrypted $false -Value $baseUri
#}
#$AutomationVariable | Set-AzureRmAutomationVariable -Value $baseUri
#$message = ('The baseUri variable was set to ' + $baseUri)

# Import the module to Azure Automation
#$ModuleStatus = $AutomationAccount | Get-AzureRmAutomationModule
#$ModuleName = "nx"
#if (($ModuleStatus | Where-Object {$_.Name -eq $ModuleName})  -eq $null)
#{
#
#    $ModuleVersion = "1.0.0"
#    $ModuleContentUrl = "https://www.powershellgallery.com/api/v2/package/$ModuleName/$ModuleVersion"
#    $ModulePackage = (Invoke-WebRequest -Uri $ModuleContentUrl -MaximumRedirection 0 -UseBasicParsing -ErrorAction Ignore).Headers.Location
#
#    $ModuleStatus = $AutomationAccount | New-AzureRmAutomationModule -Name $ModuleName -ContentLink $ModulePackage
#    $message = 'The nx Module has been added to Azure Automation'
#    Write-Host $message

#    $message = ('The module status is ' + $ModuleStatus.ProvisioningState)
    # Wait for nx module to be installed
#    while($ModuleStatus.ProvisioningState -ne "Succeeded")
#    {
#        $ModuleStatus = $ModuleStatus | Get-AzureRmAutomationModule
#        Write-Host $message
#        Start-Sleep -Seconds 3
#    }
#}

# Import the DSC Node Configuration to Azure Automation
#$AutomationAccount | Import-AzureRmAutomationDscConfiguration -SourcePath ($DSCSourceFolder + '\' + $DscConfigName + '.ps1') -Published -Force

# Compile the Configuration
#$CompilationJob = $AutomationAccount | Start-AzureRmAutomationDscCompilationJob -ConfigurationName $DscConfigName

#while($CompilationJob.EndTime -eq $null -and $CompilationJob.Exception -eq $null)
#{
#    $CompilationJob = $CompilationJob | Get-AzureRmAutomationDscCompilationJob
#    Start-Sleep -Seconds 3
#}

#$CompilationJob | Get-AzureRmAutomationDscCompilationJobOutput -Stream Any

# Get the Azure Automation info for computer registration
#$AutomationRegInfo = $AutomationAccount | Get-AzureRmAutomationRegistrationInfo

#New a guid for the automation template and the complitation job
$CompJobGuid = ([Guid]::NewGuid()).Guid

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
    $ConfigName = ($DscConfigName + '.sap-hana')

    # Deploy the SAP HANA Environment from the ARM Template
    New-AzureRmResourceGroupDeployment -Name ((Get-ChildItem $TemplateFile).BaseName + '-' + ((Get-Date).ToUniversalTime()).ToString('MMdd-HHmm')) `
                                       -TemplateFile $TemplateFile `
                                       -TemplateParameterFile $TemplateParametersFile `
                                       -ResourceGroupName $ResourceGroup_Name `
                                       -fileUri $mofUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
                                       -customUri $customScriptExtUri.ICloudBlob.StorageUri.PrimaryUri.AbsoluteUri `
                                       -baseUri $baseUri `
                                       -AzureDscUri $AutomationRegInfo.Endpoint `
                                       -AzureDscKey $AutomationRegInfo.PrimaryKey `
                                       -DscConfigName $ConfigName `
                                       -CompJobGuid $compjobguid `
                                       -Force -Verbose `
                                       -ErrorVariable ErrorMessages

# Check compliance status
$Node = $AutomationAccount | Get-AzureRmAutomationDscNode
$message = ('The DSC Node: ' + $Node.Name + ' is ' + $Node.Status)
while ($Node.Status -eq 'Pending') {
    $Node = $Node | Get-AzureRmAutomationDscNode
    Write-Host $message
    Start-Sleep -Seconds 3
}


    if ($ErrorMessages) {
        Write-Output '', 'Template deployment returned the following errors:', @(@($ErrorMessages) | ForEach-Object { $_.Exception.Message.TrimEnd("`r`n") })
    }
}
