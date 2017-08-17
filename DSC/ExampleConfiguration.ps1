
Param(
    [Parameter(Mandatory)][string] $Uri
)

Configuration ExampleConfiguration{

    Import-DSCResource -Module nx
    Set-StrictMode -Off

    Node  "sap-hana"{

nxScript insthana{

    GetScript = @"
#!/bin/bash
exit 1
"@

    SetScript = @"
#!/bin/bash
cd /hana/shared/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/shared/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/shared/sapbits/hdbinst.cfg
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
} 






    }
}
ExampleConfiguration -OutputPath:".\"