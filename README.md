# SAP HANA ARM Installation
This ARM template is used to install SAP HANA on a single VM running SUSE SLES. It uses the Azure SKU for SAP. **We will be adding additional SKUs and Linux flavors in future Versions.** The template takes advantage of [DSC for Linux](https://github.com/Azure/azure-linux-extensions/tree/master/DSC) and the [Custom Script Extensions](https://github.com/Azure/azure-linux-extensions/tree/master/CustomScript) for the installation and configuration of the machine.

## Machine Info
The template current deploys HANA on a one of the machines listed in the table below with the noted disk configuration.  The deployment takes advantage of Managed Disks, for more information on Managed Disks or the sizes of the noted disks can be found on [this](https://docs.microsoft.com/en-us/azure/storage/storage-managed-disks-overview#pricing-and-billing) page.

Machine Size | RAM | Data and Log Disks | /hana/shared | /root | /usr/sap | hana/backup
------------ | --- | ------------------ | ------------ | ----- | -------- | -----------
GS5 | 448 GB | 2 x P20 | 1 x S20 | 1 x P6 | 1 x S6 | 1 x S30

## Deploy the Solution
The solution must be run from PowerShell on Windows that is logged into Azure. It assumes you have logged in and selected the subscription to which you would like to deploy to. If this is not the case run `Login-AzureRmAccount` to get logged in. Once logged in, the current subscription should be displayed. If a different subscription is necessary, run `Get-AzureRmSubscription` to list the subscriptions and then `Select-AzureRmSubscription -SubscriptionName "YOURSUBNAME"` to select the subscription where the solution is to be deployed.

The ARM template should be deployed using the `Deploy-AzureResourceGroup.ps1` file. Execute the below example replacing `YOURNAME` with your Resource Group Name and `YOURVMNAME` with your VM name. The solution can be deployed in any location with the available sku. **We will be adding additional SKUs that will drive the available deployment locations.** For more information on Sku availability can be found on the [Azure website](https://azure.microsoft.com/en-us/pricing/details/cloud-services/).

```powershell
./Deploy-AzureResourceGroup.ps1 -ResourceGroupName YOURNAME -vmName
YOURVMNAME -ResourceGroupLocation eastus2 -UploadArtifacts -DSCSourceFolder .\DSC\
```
## Troubleshooting

