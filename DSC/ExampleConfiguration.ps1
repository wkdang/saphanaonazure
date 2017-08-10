Configuration ExampleConfiguration{

        Import-DSCResource -Module nx

        Node  "sap-hana"{
        nxFile ExampleFile {

            DestinationPath = "/tmp/example"
            Contents = "hello world `n"
            Ensure = "Present"
            Type = "File"
        }

        nxFile ExampleFile2 {

            DestinationPath = "/tmp/example2"
            Contents = "hello world `n"
            Ensure = "Present"
            Type = "File"
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

	nxPackage glibc
	{
	   Name = "glibc-2.22-51.6"
    	   Ensure = "Present"
    	   PackageManager = "zypper"
	}

	nxPackage systemd
	{
	   Name = "systemd-228-142.1"
    	   Ensure = "Present"
    	   PackageManager = "zypper"
	}

	nxPackage sapconf
	{
	   Name = "sapconf"
    	   Ensure = "Present"
    	   PackageManager = "zypper"
	}

	nxFile loginconfdir
	{
   	   Ensure = "Present"
   	   DestinationPath = "/etc/systemd/login.conf.d"
   	   Type = "Directory"
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
	   DependsOn = "[nxFile]loginconfdir"
} 


nxScript SetTunedAdm{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
tuned-adm profile sap-hana
systemctl start tuned
systemctl enable tuned
saptune solution apply HANA
saptune daemon start
"@

    TestScript = @'
#!/bin/bash
exit 1
'@
} 

	nxFileLine BootConf
	{
	   FilePath = "/etc/default/grub"
	   ContainsLine = 'GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=never numa_balancing=disable intel_idle.max_cstate=1 processor.max_cstate=1"'
	} 

nxScript grubmkconfig{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
grub2-mkconfig -o /boot/grub2/grub.cfg
echo 1 > /root/boot-requested
"@

    TestScript = @'
#!/bin/bash
filecount=`cat /root/boot-done`
if [ $filecount -gt 0 ]
then
    exit 0
else
    exit 1
fi
'@

	   DependsOn = "[nxFileLine]BootConf"
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
filecount=`cat /root/boot-requested`
if [ $filecount -gt 0 ]
then
    exit 1
else
    exit 0
fi

'@

	   DependsOn = "[nxFileLine]BootConf"
} 

nxScript physicalvols{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
pvcreate /dev/sd[cdefg]
"@

    TestScript = @'
#!/bin/bash
filecount=`pvdisplay | grep sd[cdefg] | wc -l`
if [ $filecount -gt 0 ]
then
    exit 0
else
    exit 1
fi

'@

} 

nxScript logicalvols{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
vgcreate hanavg /dev/sd[fg]
lvcreate -l 80%FREE -n datalv hanavg
lvcreate -l 20%FREE -n loglv hanavg
mkfs.xfs /dev/hanavg/datalv
mkfs.xfs /dev/hanavg/loglv
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
	DependsOn="[nxScript]physicalvols"
} 

	nxFile hanadatadir
	{
   	   Ensure = "Present"
   	   DestinationPath = "/hanadata"
   	   Type = "Directory"
	}

	nxFile hanalogdir
	{
   	   Ensure = "Present"
   	   DestinationPath = "/hanalog"
   	   Type = "Directory"
	}




        }
    }
    ExampleConfiguration -OutputPath:".\"