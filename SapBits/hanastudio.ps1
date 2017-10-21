param (

    [string]$baseUri,
)

#Get the bits for the HANA installation and copy them to C:\SAPbits\SAP_HANA_STUDIO\
$hanasource = $baseUri + "\SAPbits\SAP_HANA_STUDIO\"

$hanadest = "C:\SAPbits\SAP_HANA_STUDIO\"

New-Item -Path $hanadest -ItemType directory

Invoke-WebRequest $hanasource -OutFile "$hanadest"

$jresource = $baseUri + "\SAPbits\JRE\"

$jredest = "C:\Program Files\"

New-Item -Path $jredest -ItemType directory

Invoke-WebRequest $jresource -OutFile "$jredest"

set PATH=%PATH%C:\Program Files\jdk-9\bin;
set HDB_INSTALLER_TRACE_FILE=C:\Users\testuser\Documents\hdbinst.log
cd C:\SAPbits\SAP_HANA_STUDIO\studio
hdbinst -a C:\SAPbits\SAP_HANA_STUDIO\studio -b --path="C:\Program Files\sap\hdbstudio"