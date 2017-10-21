param (

    [string]$baseUri
)

#Get the bits for the HANA installation and copy them to C:\SAPbits\SAP_HANA_STUDIO\
$sapcarUri = $baseUri + "/SAPbits/SAP_HANA_STUDIO/sapcar.exe"
$hanastudioUri = $baseUri + "/SAPbits/SAP_HANA_STUDIO/IMC_STUDIO2_212_2-80000323.SAR"
$jreUri = $baseUri + "/SAPbits/SAP_HANA_STUDIO/serverjre-9.0.1_windows-x64_bin.tar.gz"
$7zUri = $baseUri + "/SAPbits/SAP_HANA_STUDIO/7z.exe"
$hanadest = "C:\SAPbits\SAP_HANA_STUDIO"
$jredest = "C:\Program Files"
New-Item -Path $hanadest -ItemType directory

Invoke-WebRequest $sapcarUri -OutFile $hanadest
Invoke-WebRequest $hanastudioUri -OutFile $hanadest
Invoke-WebRequest $jreUri -OutFile $jredest
Invoke-WebRequest $7zUri -OutFile $jredest

cd $jredest
.\7z.exe e .\serverjre-9.0.1_windows-x64_bin.tar.gz
.\7z.exe x -y "-oC:\ProgramFiles" "C:\ProgramFiles\serverjre-9.0.1_windows-x64_bin.tar"

cd $hanadest
.\sapcar.exe -xfv IMC_STUDIO2_212_2-80000323.SAR

set PATH=%PATH%C:\Program Files\jdk-9\bin;
set HDB_INSTALLER_TRACE_FILE=C:\Users\testuser\Documents\hdbinst.log
cd C:\SAPbits\SAP_HANA_STUDIO\studio
hdbinst -a C:\SAPbits\SAP_HANA_STUDIO\studio -b --path="C:\Program Files\sap\hdbstudio"