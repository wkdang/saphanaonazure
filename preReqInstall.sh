AZ_URI=$2
AZ_KEY=$1

# Install PowerShell
wget https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-beta.5/powershell-6.0.0_beta.5-1.suse.42.1.x86_64.rpm
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo zypper info libuuid-devel
sudo rpm -Uvh --nodeps ./powershell-6.0.0_beta.5-1.suse.42.1.x86_64.rpm

#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y sapconf
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /hana
sudo mkdir /hana/data
sudo mkdir /hana/log
sudo mkdir /hana/shared
sudo mkdir /hana/backup
sudo mkdir /usr/sap


# Install .NET Core and AzCopy
sudo zypper install -y libunwind
sudo zypper install -y libicu
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

#do more SAP configuration
tuned-adm profile sap-hana
systemctl start tuned
systemctl enable tuned
saptune solution apply HANA
saptune daemon start
echo 'GRUB_CMDLINE_LINUX_DEFAULT="transparent_hugepage=never numa_balancing=disable intel_idle.max_cstate=1 processor.max_cstate=1"' >>/etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg
echo 1 > /root/boot-requested

# Register Node for Azure Automation DSC Management
sudo /opt/microsoft/dsc/Scripts/Register.py --RegistrationKey $AZ_KEY --ServerURL $AZ_URI --ConfigurationMode ApplyAndAutoCorrect --RefreshMode Pull --ConfigurationName ExampleConfiguration.sap-hana

