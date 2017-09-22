Configuration Standard_M64s{

    $Uri = Get-AutomationVariable -Name 'baseUri'

    Import-DSCResource -Module nx
    Set-StrictMode -Off

    Node  "sap-hana"{

    nxFile uritest
    {
	Ensure = "Present"
	DestinationPath = "/tmp/url.txt"
	Contents="$Uri"
    }

	nxFileLine EnableSwap
	{
	   FilePath = "/etc/waagent.conf"
       	   ContainsLine = 'ResourceDisk.EnableSwap = y'
	   DoesNotContainPattern = "ResourceDisk.EnableSwap=n"
	} 

	nxFileLine EnableSwapSize
	{
	   FilePath = "/etc/waagent.conf"
	   ContainsLine = 'ResourceDisk.SwapSizeMB = 163840'
	} 

	nxFile setLoginconfd
	{
	   Ensure = "Present"
    	   Destinationpath = "/etc/systemd/login.conf.d/sap.conf"
    	   Contents=@"
[login]`n
UserTasksMax=infinity`n
"@ 
	   Mode = "755"
} 

nxScript logicalvols{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
echo "logicalvols start" >> /tmp/parameter.txt
pvcreate /dev/sd[cdefgh]
vgcreate hanavg /dev/sd[gh]
lvcreate -l 80%FREE -n datalv hanavg
lvcreate -l 20%FREE -n loglv hanavg
mkfs.xfs /dev/hanavg/datalv
mkfs.xfs /dev/hanavg/loglv
echo "logicalvols start" >> /tmp/parameter.txt
"@

    TestScript = @'
#!/bin/bash
filecount=`vgdisplay | grep hanavg | wc -l`
if [ $filecount -gt 0 ]
then
    exit 0
else
    exit 1
fi

'@
} 

nxScript logicalvols2{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
vgcreate sharedvg /dev/sdc 
vgcreate backupvg /dev/sd[ef]  
vgcreate usrsapvg /dev/sdd 
lvcreate -l 100%FREE -n sharedlv sharedvg 
lvcreate -l 100%FREE -n backuplv backupvg 
lvcreate -l 100%FREE -n usrsaplv usrsapvg 
mkfs -t xfs /dev/sharedvg/sharedlv 
mkfs -t xfs /dev/backupvg/backuplv 
mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt
"@

    TestScript = @'
#!/bin/bash
filecount=`vgdisplay | grep -E "sharedvg|backupvg|usrsapvg" | wc -l`
if [ $filecount -gt 2 ]
then
    filecount=`lvdisplay | grep -E "LV Name" | wc -l`
    if [ $filecount -gt 4 ]
    then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi

'@
} 


	nxFileLine fstabshared
	{
	   FilePath = "/etc/fstab"
       	   ContainsLine = '/dev/sharedvg/sharedlv /hana/shared xfs defaults 1 0 '
	} 

	nxFileLine fstabbackup
	{
	   FilePath = "/etc/fstab"
       	   ContainsLine = '/dev/backupvg/backuplv /hana/backup xfs defaults 1 0 '
	} 

	nxFileLine fstabusrsap
	{
	   FilePath = "/etc/fstab"
       	   ContainsLine = '/dev/usrsapvg/usrsaplv /usr/sap xfs defaults 1 0 '
	} 

	nxFileLine fstabdatalv
	{
	   FilePath = "/etc/fstab"
       	   ContainsLine = '/dev/hanavg/datalv /hana/data xfs nofail 0 0  '
	} 

	nxFileLine fstabloglv
	{
	   FilePath = "/etc/fstab"
       	   ContainsLine = '/dev/hanavg/loglv /hana/log xfs nofail 0 0  '
	} 


nxScript mounthanashared{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mkdir /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt
exit 0
"@

    TestScript = @'
#!/bin/bash
filecount=`mount | grep -E "hana|sap" | wc -l`
if [ $filecount -gt 4 ]
then
    exit 0
else
    exit 1
fi
'@

} 

nxFile sapbitsdir
{
   Ensure = "Present"
   DestinationPath = "/hana/data/sapbits"
   Type = "Directory"
   DependsOn = '[nxScript]mounthanashared'   
}

nxFile md5sums
{
    SourcePath = "$Uri/SapBits/md5sums"
    DestinationPath = "/hana/data/sapbits/md5sums"
    Type = "file"
    DependsOn = '[nxFile]sapbitsdir'   
}

nxScript downloadsapbits{

    GetScript = @'
#!/bin/bash
exit 1
'@
    SetScript = @"
#!/bin/bash
cd /hana/data/sapbits
/usr/bin/wget --quiet $Uri/SapBits/51052325_part1.exe
/usr/bin/wget --quiet $Uri/SapBits/51052325_part2.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part3.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part4.rar
/usr/bin/wget --quiet $Uri/SapBits/hdbinst.cfg
"@
    TestScript = @'
#!/bin/bash
date >> /tmp/testdate
cd /hana/data/sapbits
rarfilecount=`ls -1 | grep "rar" | wc -l`
if [ $rarfilecount -lt 3 ]
then
    exit 1
else
    ckfilecount=`ls -1 | grep md5sums.checked | wc -l`
    if [ $ckfilecount -gt 0 ]
    then
        exit 0
    fi
    mdstat=`md5sum --status -c md5sums`
    if [ $mdstat -gt 0 ]
    then
        exit 1
    else
	cp md5sums md5sums.checked    
        exit 0
    fi	
fi
'@
DependsOn = '[nxFile]md5sums'
} 


nxScript unpackrar{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
cd /hana/data/sapbits
unrar -inul x 51052325_part1.exe
"@

    TestScript = @'
#!/bin/bash
cd /hana/data/sapbits
sbfilecount=`ls -1 | grep 51052325 | grep -v part| wc -l`
if [ $sbfilecount -gt 0 ]
then
    ssfilecount=`find /hana/data/sapbits/51052325 | wc -l`
    if [ $ssfilecount -gt 5365 ]
    then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi

'@
DependsOn = '[nxScript]downloadsapbits'
} 


nxScript hdbinstconfig{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @'
#!/bin/bash
cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 > hdbinst-local.cfg
exit 0
'@

    TestScript = @'
#!/bin/bash
cd /hana/data/sapbits
filecount=`ls -1 | grep hdbinst-local.cfg  | wc -l`
if [ $filecount -gt 0 ]
then
    filecount=`grep -s hostname= /hana/data/sapbits/hdbinst-local.cfg | wc -l`
    if [ $filecount -gt 0 ]
    then
        exit 0
    else
        exit 1
    fi
else
    exit 1
fi
'@
    DependsOn = '[nxScript]unpackrar'
} 


nxScript bootrequest{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
mv /root/boot-requested /root/boot-done
reboot
"@

    TestScript = @'
#!/bin/bash
filecount=`ls /root | grep boot-requested | wc -l`
if [ $filecount -gt 0 ]
then
    exit 1
else
    exit 0
fi
'@

} 




nxScript insthana{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
cd /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
"@

    TestScript = @'
#!/bin/bash
filecount=`cat /etc/passwd | grep sapadm | wc -l`
if [ $filecount -gt 0 ]
then
    exit 0
else
    exit 1
fi

'@
	DependsOn = '[nxScript]hdbinstconfig'
} 




    }
}
Standard_M64s -OutputPath:".\"
