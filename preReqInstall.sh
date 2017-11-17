Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5


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

sudo zypper se -t pattern
sudo zypper in -t pattern sap-hana

# step2
echo $Uri >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB = 16384/ResourceDisk.SwapSizeMB = 16384/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf

cp -f /etc/systemd/login.conf.d/sap.conf /etc/systemd/login.conf.d/sap.conf.orig
sedcmd="s/[login]`n
UserTasksMax=infinity`n/[login]`n
UserTasksMax=infinity`n/g"
cat /etc/systemd/login.conf.d/sap.conf | sed $sedcmd > //etc/systemd/login.conf.d/sap.conf.new
cp -f /etc/systemd/login.conf.d/sap.conf.new /etc/systemd/login.conf.d/sap.conf

echo "logicalvols start" >> /tmp/parameter.txt
pvcreate /dev/sd[cdefg]
vgcreate hanavg /dev/sd[fg]
lvcreate -l 80%FREE -n datalv hanavg
lvcreate -l 20%FREE -n loglv hanavg
mkfs.xfs /dev/hanavg/datalv
mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
vgcreate sharedvg /dev/sdc 
vgcreate usrsapvg /dev/sdd
vgcreate backupvg /dev/sde  
 
lvcreate -l 100%FREE -n sharedlv sharedvg 
lvcreate -l 100%FREE -n backuplv backupvg 
lvcreate -l 100%FREE -n usrsaplv usrsapvg 
mkfs -t xfs /dev/sharedvg/sharedlv 
mkfs -t xfs /dev/backupvg/backuplv 
mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt


#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mkdir /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt

if [ ! -d "/hana/data/sapbits" ]
 then
 mkdir "/hana/data/sapbits"
fi



#!/bin/bash
cd /hana/data/sapbits
echo "hana download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $Uri/SapBits/md5sums
/usr/bin/wget --quiet $Uri/SapBits/51052325_part1.exe
/usr/bin/wget --quiet $Uri/SapBits/51052325_part2.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part3.rar
/usr/bin/wget --quiet $Uri/SapBits/51052325_part4.rar
/usr/bin/wget --quiet $Uri/SapBits/hdbinst.cfg
echo "hana download end" >> /tmp/parameter.txt

date >> /tmp/testdate
cd /hana/data/sapbits

echo "hana unrar start" >> /tmp/parameter.txt
#!/bin/bash
cd /hana/data/sapbits
unrar -inul x 51052325_part1.exe
echo "hana unrar end" >> /tmp/parameter.txt

echo "hana prepare start" >> /tmp/parameter.txt
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

#!/bin/bash
cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/root_password=AweS0me@PW/root_password=$HANAPWD/g"
sedcmd5="s/sid=H10/sid=$HANASID/g"
sedcmd6="s/number=00/number=$HANANUMBER/g"
cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
echo "hana preapre end" >> /tmp/parameter.txt

#!/bin/bash
echo "install hana start" >> /tmp/parameter.txt
cd /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
echo "install hana end" >> /tmp/parameter.txt
