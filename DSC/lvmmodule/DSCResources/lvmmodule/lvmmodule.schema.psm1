Configuration lvmmodule{
    
    param
    (
        #Physical Disk Name Parameter i.e. /dev/sdc
        [parameter(Mandatory=$true,ParameterSetName="PhysicalDisk")]
        [string]$disk,
        #Name of the volume group you want to create
        [parameter(Mandatory=$true,ParameterSetName="VolumeGroup")]
        [string]$vgname,
        #Name of the physical disks which are to be included in the volume group
        #i.e. /dev/sdc /dev/sdd 
        [parameter(Mandatory=$true,ParameterSetName="VolumeGroup")]
        [string]$vgdisks,
        #name of the logical volume group 
        [parameter(Mandatory=$true,ParameterSetName="LogicalGroup")]
        [string]$lvgroup,
        #Name of the logical volume name
        [parameter(Mandatory=$true,ParameterSetName="LogicalGroup")]
        [string]$lvname,
        #name of the Virtual Machine to execute against
        [parameter(Mandatory=$true,ParameterSetName="PhysicalDisk")]
        [parameter(Mandatory=$true,ParameterSetName="LogicalGroup")]
        [parameter(Mandatory=$true,ParameterSetName="VolumeGroup")]
        [string]$vmname="sap-hana"
)
        
        
        Import-DSCResource -Module nx

        Node $vmname{

    
nxscript physicalvolume
{
GetScript = @"
#!/bin/bash
exit 1
"@

SetScript = @"
#!/bin/bash
echo "physicalvolume start" >> /tmp/parameter.txt
pvcreate $disk
"@

TestScript = @"
#!/bin/bash
exit 1
"@
}
        }
nxscript volumegroup
{
GetScript = @"
#!/bin/bash
exit 1
"@

SetScript = @"
#!/bin/bash
echo "volumegroup start" >> /tmp/parameter.txt
vgcreate $vgname $vgdisks
"@

TestScript = @"
#!/bin/bash
exit 1
"@
}

nxscript logicalvolume
{
GetScript = @"
#!/bin/bash
exit 1
"@

SetScript = @"
#!/bin/bash
echo "logcialvolume start" >> /tmp/parameter.txt
lvcreate -l 100%FREE -n $lvname $lvgroup
mkfs -t xfs /dev/$lvgroup/$lvname 
"@ 

TestScript = @"
#!/bin/bash
exit 1
"@
}
}

}
    
        