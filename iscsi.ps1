Param(
  [string]$vmname1,
  [string]$vmname2,
  [string]$ipaddress1,
  [string]$ipaddress2
)
Import-Module -Name ServerManager
Add-WindowsFeature -Name FS-iSCSITarget-Server
Import-Module -Name iSCSITarget
$iqn1 = "IQN:iqn.1991-05.com.microsoft:hanajb-hsrtarget-target:"+$vmname1
$iqn2 = "IQN:iqn.1991-05.com.microsoft:hanajb-hsrtarget-target:"+$vmname2
$ip1 ="IPAddress:"+$ipaddress1
$ip2 ="IPAddress:"+$ipaddress2
New-IscsiVirtualDisk -Path c:\pacemaker\lun.vhdx -Size 1GB
New-IscsiServerTarget -TargetName HSRTarget -InitiatorId @($ip1,$ip2,$iqn1,$iqn2)
Add-IscsiVirtualDiskTargetMapping -TargetName HSRTarget -Path C:\pacemaker\lun.vhdx
Enable-WindowsOptionalFeature -Online -Featurename MultipathIO -NoRestart
Restart-Computer -Force