param (
    
        [string]$baseUri,
        [string]$vmname1,
        [string]$vmname2,
        [string]$ipaddress1,
        [string]$ipaddress2
    )
    #Get the bits for the HANA installation and copy them to C:\SAPbits\SAP_HANA_STUDIO\
    $hanadest = "C:\SapBits"
    $sapcarUri = $baseUri + "/SapBits/SAP_HANA_STUDIO/sapcar.exe" 
    $hanastudioUri = $baseUri + "/SapBits/SAP_HANA_STUDIO/IMC_STUDIO2_212_2-80000323.SAR" 
    $jreUri = $baseUri + "/SapBits/SAP_HANA_STUDIO/serverjre-9.0.1_windows-x64_bin.tar.gz" 
    $7zUri = "https://www.7-zip.org/a/7z1801-x64.msi"
    $sapcardest = "C:\SapBits\SAP_HANA_STUDIO\sapcar.exe"
    $hanastudiodest = "C:\SapBits\SAP_HANA_STUDIO\IMC_STUDIO2_212_2-80000323.SAR"
    $jredest = "C:\Program Files\serverjre-9.0.4_windows-x64_bin.tar.gz"
    $7zdest = "C:\Program Files\7z.msi"
    $jrepath = "C:\Program Files"
    $hanapath = "C:\SapBits\SAP_HANA_STUDIO"
    if((test-path $hanadest) -eq $false)
    {
        New-Item -Path $hanadest -ItemType directory
        New-item -Path $hanapath -itemtype directory
    }
    write-host "downloading files"
    Invoke-WebRequest $sapcarUri -OutFile $sapcardest
    Invoke-WebRequest $hanastudioUri -OutFile $hanastudiodest
    Invoke-WebRequest $jreUri -OutFile $jredest
    Invoke-WebRequest $7zUri -OutFile $7zdest
    
    cd $jrepath
    .\7z.msi /quiet
    cd "C:\Program Files\7-Zip\"
    .\7z.exe e "C:\Program Files\serverjre-9.0.1_windows-x64_bin.tar.gz" "-oC:\Program Files"
    .\7z.exe x -y "C:\Program Files\serverjre-9.0.1_windows-x64_bin.tar" "-oC:\Program Files"
    
    cd $hanapath
    .\sapcar.exe -xfv IMC_STUDIO2_212_2-80000323.SAR
    
    set PATH=%PATH%C:\Program Files\jdk-9.0.1\bin;
    set HDB_INSTALLER_TRACE_FILE=C:\Users\testuser\Documents\hdbinst.log
    cd C:\SAPbits\SAP_HANA_STUDIO\SAP_HANA_STUDIO\
    .\hdbinst.exe -a C:\SAPbits\SAP_HANA_STUDIO\SAP_HANA_STUDIO\studio -b --path="C:\Program Files\sap\hdbstudio"
Import-Module -Name ServerManager
Add-WindowsFeature -Name FS-iSCSITarget-Server
Import-Module -Name iSCSITarget
$iqn1 = "IQN:iqn.1991-05.com.microsoft:hanajb-hsrtarget-target:"+$vmname1
$iqn2 = "IQN:iqn.1991-05.com.microsoft:hanajb-hsrtarget-target:"+$vmname2
$ip1 ="IPAddress:"+$ipaddress1
$ip2 ="IPAddress:"+$ipaddress2
New-IscsiVirtualDisk -Path c:\pacemaker\lun.vhdx -Size 1GB
Start-Sleep 5
New-IscsiServerTarget -TargetName HSRTarget -InitiatorId @($ip1,$ip2,$iqn1,$iqn2)
Start-Sleep 5
Add-IscsiVirtualDiskTargetMapping -TargetName HSRTarget -Path C:\pacemaker\lun.vhdx
Start-Sleep 5
Enable-WindowsOptionalFeature -Online -Featurename MultipathIO -NoRestart
Start-Sleep 5
Restart-Computer -Force
