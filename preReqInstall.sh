AZ_URI=$2
AZ_KEY=$1
DSC_CONFIG_NAME=$3

# Install PowerShell
wget https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-beta.5/powershell-6.0.0_beta.5-1.suse.42.1.x86_64.rpm
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo zypper info libuuid-devel
sudo rpm -Uvh --nodeps ./powershell-6.0.0_beta.5-1.suse.42.1.x86_64.rpm

# Install .NET Core and AzCopy
sudo zypper install libunwind libicu
curl -sSL -o dotnet.tar.gz https://go.microsoft.com/fwlink/?linkid=848824
sudo mkdir -p /opt/dotnet && sudo tar zxf dotnet.tar.gz -C /opt/dotnet
sudo ln -s /opt/dotnet/dotnet /usr/bin

wget -O azcopy.tar.gz https://aka.ms/downloadazcopyprlinux
tar -xf azcopy.tar.gz
sudo ./install.sh

# Install DSC for Linux
wget https://github.com/Microsoft/omi/releases/download/v1.1.0-0/omi-1.1.0.ssl_100.x64.rpm
wget https://github.com/Microsoft/PowerShell-DSC-for-Linux/releases/download/v1.1.1-294/dsc-1.1.1-294.ssl_100.x64.rpm

sudo rpm -Uvh omi-1.1.0.ssl_100.x64.rpm dsc-1.1.1-294.ssl_100.x64.rpm

# Register Node for Azure Automation DSC Management
sudo /opt/microsoft/dsc/Scripts/Register.py --RegistrationKey $AZ_KEY --ServerURL $AZ_URI --ConfigurationName $DSC_CONFIG_NAME --RefreshFrequencyMins 5 --ConfigurationMode ApplyAndAutoCorrect --ConfigurationModeFrequencyMins 10