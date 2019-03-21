#!/bin/bash
set -x

Uri=$1
HANAUSR=$2
HANAPWD=$3
HANASID=$4
HANANUMBER=$5
HANAVERS=$6
OS=$7
vmSize=$8

echo $1 >> /tmp/parameter.txt
echo $2 >> /tmp/parameter.txt
echo $3 >> /tmp/parameter.txt
echo $4 >> /tmp/parameter.txt
echo $5 >> /tmp/parameter.txt
echo $6 >> /tmp/parameter.txt
echo $7 >> /tmp/parameter.txt
echo $8 >> /tmp/parameter.txt

sed -i -e "s/Defaults    requiretty/#Defaults    requiretty/g" /etc/sudoers
	sudo mkdir -p /hana/{data,log,shared,backup}
	sudo mkdir /usr/sap

	
#get the VM size via the instance api
VMSIZE=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01&format=text"`
echo $VMSIZE >> /tmp/parameter.txt

if [ "$7" == "RHEL" ]; then
	echo "Start REHL prerequisite" >> /tmp/parameter.txt
	yum -y groupinstall base
	yum -y install gtk2 libicu xulrunner sudo tcsh libssh2 expect cairo graphviz iptraf-ng 
	yum -y install compat-sap-c++-6
	sudo mkdir -p /hana/{data,log,shared,backup}
	sudo mkdir /usr/sap
	sudo mkdir -p /hana/data/{sapbitslocal,sapbits}
	yum -y install tuned-profiles-sap-hana
	systemctl start tuned
	systemctl enable tuned
	tuned-adm profile sap-hana
	setenforce 0
	#sed -i 's/\(SELINUX=enforcing\|SELINUX=permissive\)/SELINUX=disabled/g' \ > /etc/selinux/config
	echo "start SELINUX" >> /tmp/parameter.txt
	sed -i -e "s/\(SELINUX=enforcing\|SELINUX=permissive\)/SELINUX=disabled/g" /etc/selinux/config
	echo "end SELINUX" >> /tmp/parameter.txt
	echo "kernel.numa_balancing = 0" > /etc/sysctl.d/sap_hana.conf
	ln -s /usr/lib64/libssl.so.1.0.1e /usr/lib64/libssl.so.1.0.1
	ln -s /usr/lib64/libcrypto.so.0.9.8e /usr/lib64/libcrypto.so.0.9.8
	ln -s /usr/lib64/libcrypto.so.1.0.1e /usr/lib64/libcrypto.so.1.0.1
	echo always > /sys/kernel/mm/transparent_hugepage/enabled
	echo never > /sys/kernel/mm/transparent_hugepage/enabled
	echo "start Grub" >> /tmp/parameter.txt
	sedcmd="s/rootdelay=300/rootdelay=300 transparent_hugepage=never intel_idle.max_cstate=1 processor.max_cstate=1/g"
	sudo sed -i -e "$sedcmd" /etc/default/grub
	echo "start Grub2" >> /tmp/parameter.txt
	sudo grub2-mkconfig -o /boot/grub2/grub.cfg
	echo "End Grub" >> /tmp/parameter.txt
    echo "@sapsys         soft    nproc   unlimited" >> /etc/security/limits.d/99-sapsys.conf
	systemctl disable abrtd
	systemctl disable abrt-ccpp
	systemctl stop abrtd
	systemctl stop abrt-ccpp
	systemctl stop kdump.service
	systemctl disable kdump.service
	systemctl stop firewalld
	systemctl disable firewalld
	sudo mkdir -p /sources
	yum -y install cifs-utils
	# Install Unrar  
	echo "start RAR" >> /tmp/parameter.txt
	wget http://www.rarlab.com/rar/unrar-5.0-RHEL5x64.tar.gz 
	tar -zxvf unrar-5.0-RHEL5x64.tar.gz 
	cp unrar /usr/bin/ 
	chmod 755 /usr/bin/unrar 
	echo "End RAR" >> /tmp/parameter.txt
	echo "End REHL prerequisite" >> /tmp/parameter.txt
	
else
#install hana prereqs
	sudo zypper install -y glibc-2.22-51.6
	sudo zypper install -y systemd-228-142.1
	sudo zypper install -y unrar
	sudo zypper install -y sapconf
	sudo zypper install -y saptune
	sudo mkdir /etc/systemd/login.conf.d
	sudo mkdir -p /hana/{data,log,shared,backup}
	sudo mkdir /usr/sap
	sudo mkdir -p /hana/data/{sapbitslocal,sapbits}



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
	sudo zypper --non-interactive in -t pattern sap-hana 
fi


# step2
echo $Uri >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf
#sed -i -e "s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g" -e "s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g" /etc/waagent.conf

# this assumes that 5 disks are attached at lun 0 through 4
echo "start Creating partitions and physical volumes" >> /tmp/parameter.txt
sudo pvcreate -ff -y /dev/disk/azure/scsi1/lun0   
sudo pvcreate -ff -y  /dev/disk/azure/scsi1/lun1
sudo pvcreate -ff -y  /dev/disk/azure/scsi1/lun2
sudo pvcreate -ff -y  /dev/disk/azure/scsi1/lun3
sudo pvcreate -ff -y  /dev/disk/azure/scsi1/lun4
sudo pvcreate -ff -y  /dev/disk/azure/scsi1/lun5
echo "End creating partitions and physical volumes" >> /tmp/parameter.txt

if [ $VMSIZE == "Standard_M128ms" ] || [ $VMSIZE == "Standard_M208ms_v2" ]; then

  # this assumes that 6 disks are attached at lun 0 through 5
  echo "Creating partitions and physical volumes"
sudo   pvcreate -ff -y  /dev/disk/azure/scsi1/lun6
sudo   pvcreate -ff -y  /dev/disk/azure/scsi1/lun7
sudo   pvcreate  -ff -y /dev/disk/azure/scsi1/lun8
sudo   pvcreate  -ff -y /dev/disk/azure/scsi1/lun9
sudo   pvcreate  -ff -y /dev/disk/azure/scsi1/lun10

  echo "shared logicalvols start" >> /tmp/parameter.txt
  #shared volume creation
sudo sharedvglun="/dev/disk/azure/scsi1/lun0"
sudo vgcreate sharedvg $sharedvglun
sudo lvcreate -l 100%FREE -n sharedlv sharedvg 
  echo "usr logicalvols stop" >> /tmp/parameter.txt 
  #usr volume creation
  echo "backup logicalvols start" >> /tmp/parameter.txt
sudo   usrsapvglun="/dev/disk/azure/scsi1/lun1"
sudo   vgcreate usrsapvg $usrsapvglun
sudo   lvcreate -l 100%FREE -n usrsaplv usrsapvg
echo "usr logicalvols stop" >> /tmp/parameter.txt

echo "backup logicalvols start" >> /tmp/parameter.txt
  #backup volume creation
sudo   backupvg1lun="/dev/disk/azure/scsi1/lun2"
sudo   backupvg2lun="/dev/disk/azure/scsi1/lun3"
sudo   vgcreate backupvg $backupvg1lun $backupvg2lun
sudo   lvcreate -l 100%FREE -n backuplv backupvg 
echo "backup logicalvols stop" >> /tmp/parameter.txt

echo "data logicalvols start" >> /tmp/parameter.txt
  #data volume creation
sudo   datavg1lun="/dev/disk/azure/scsi1/lun4"
sudo   datavg2lun="/dev/disk/azure/scsi1/lun5"
sudo   datavg3lun="/dev/disk/azure/scsi1/lun6"
sudo   datavg4lun="/dev/disk/azure/scsi1/lun7"
sudo   datavg5lun="/dev/disk/azure/scsi1/lun8"
sudo   vgcreate datavg $datavg1lun $datavg2lun $datavg3lun $datavg4lun $datavg5lun
sudo   PHYSVOLUMES=4
sudo   STRIPESIZE=64
sudo   lvcreate -i$PHYSVOLUMES -I$STRIPESIZE -l 100%FREE -n datalv datavg
echo "data logicalvols stop" >> /tmp/parameter.txt

echo "log logicalvols start" >> /tmp/parameter.txt
  #log volume creation
sudo   logvg1lun="/dev/disk/azure/scsi1/lun9"
sudo   logvg2lun="/dev/disk/azure/scsi1/lun10"
sudo   vgcreate logvg $logvg1lun $logvg2lun
sudo   PHYSVOLUMES=2
sudo   STRIPESIZE=32
sudo   lvcreate -i$PHYSVOLUMES -I$STRIPESIZE -l 100%FREE -n loglv logvg
sudo   mount -t xfs /dev/logvg/loglv /hana/log 
  echo "/dev/mapper/logvg-loglv /hana/log xfs defaults 0 0" >> /etc/fstab
echo "backup logicalvols start" >> /tmp/parameter.txt

echo "start mkfs" >> /tmp/parameter.txt
sudo   mkfs.xfs /dev/datavg/datalv
sudo   mkfs.xfs /dev/logvg/loglv
sudo   mkfs -t xfs /dev/sharedvg/sharedlv 
sudo   mkfs -t xfs /dev/backupvg/backuplv 
sudo   mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "stop mkfs" >> /tmp/parameter.txt
fi

#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
sudo mount -t xfs /dev/sharedvg/sharedlv /hana/shared
sudo mount -t xfs /dev/backupvg/backuplv /hana/backup 
sudo mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
sudo mount -t xfs /dev/datavg/datalv /hana/data
echo "mounthanashared end" >> /tmp/parameter.txt

echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/datavg-datalv /hana/data xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv /hana/shared xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv /hana/backup xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

if [ ! -d "/mnt/resource/sapbits" ]; then
sudo   mkdir -p "/mnt/resource/sapbits"
fi

if [ "$6" == "2.0" ]; then
  cd /mnt/resource/sapbits
  echo "hana 2.0 download start" >> /tmp/parameter.txt
sudo   /usr/bin/wget --quiet $Uri/SapBits/md5sums
sudo   /usr/bin/wget --quiet $Uri/SapBits/51053381_part1.exe
sudo   /usr/bin/wget --quiet $Uri/SapBits/51053381_part2.rar
sudo   /usr/bin/wget --quiet $Uri/SapBits/51053381_part3.rar
sudo   /usr/bin/wget --quiet $Uri/SapBits/51053381_part4.rar
sudo   /usr/bin/wget --quiet "https://raw.githubusercontent.com/wkdang/SAPonAzure/master/hdbinst1.cfg"
  echo "hana 2.0 download end" >> /tmp/parameter.txt

  date >> /tmp/testdate
  cd /mnt/resource/sapbits

  echo "hana 2.0 unrar start" >> /tmp/parameter.txt
  cd /mnt/resource/sapbits
sudo   unrar x 51053381_part1.exe
  echo "hana 2.0 unrar end" >> /tmp/parameter.txt

  echo "hana 2.0 prepare start" >> /tmp/parameter.txt
  cd /mnt/resource/sapbits

  cd /mnt/resource/sapbits
sudo   myhost=`hostname`
sudo   sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sudo   sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51053381/g"
sudo   sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
  #sedcmd4="s/root_password=AweS0me@PW/root_password=$HANAPWD/g"
sudo   sedcmd4="s/password=AweS0me@PW/password=$HANAPWD/g"
sudo   sedcmd5="s/sid=H10/sid=$HANASID/g"
sudo   sedcmd6="s/number=00/number=$HANANUMBER/g"
  #cat hdbinst1.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
sudo   cp -f /mnt/resource/sapbits/hdbinst1.cfg /mnt/resource/sapbits/hdbinst-local.cfg
sudo   sed -i -e $sedcmd -e $sedcmd2 -e $sedcmd3 -e $sedcmd4 -e $sedcmd5 -e $sedcmd6 /mnt/resource/sapbits/hdbinst-local.cfg
  echo "hana 2.0 prepare end" >> /tmp/parameter.txt

  echo "install hana 2.0 start" >> /tmp/parameter.txt
sudo   cd /mnt/resource/sapbits/51053381/DATA_UNITS/HDB_LCM_LINUX_X86_64
sudo   /mnt/resource/sapbits/51053381/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /mnt/resource/sapbits/hdbinst-local.cfg
  echo "Log file written to '/var/tmp/hdb_H10_hdblcm_install_xxx/hdblcm.log' on host 'saphanaarm'." >> /tmp/parameter.txt
  echo "install hana 2.0 end" >> /tmp/parameter.txt

else
  cd /mnt/resource/sapbits
echo "hana 1.0 download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $Uri/SapBits/md5sums
/usr/bin/wget --quiet $Uri/SapBits/51052383_part1.exe
/usr/bin/wget --quiet $Uri/SapBits/51052383_part2.rar
/usr/bin/wget --quiet $Uri/SapBits/51052383_part3.rar
/usr/bin/wget --quiet "https://raw.githubusercontent.com/wkdang/SAPonAzure/master/hdbinst.cfg"
echo "hana 1.0 download end" >> /tmp/parameter.txt

date >> /tmp/testdate
cd /mnt/resource/sapbits

echo "hana 1.0 unrar start" >> /tmp/parameter.txt
cd /mnt/resource/sapbits
unrar x 51052383_part1.exe
echo "hana 1.0 unrar end" >> /tmp/parameter.txt

echo "hana 1.0 prepare start" >> /tmp/parameter.txt
cd /mnt/resource/sapbits

cd /mnt/resource/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052383/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/password=AweS0me@PW/password=$HANAPWD/g"
sedcmd5="s/sid=H10/sid=$HANASID/g"
sedcmd6="s/number=00/number=$HANANUMBER/g"
#cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
cp -f /mnt/resource/sapbits/hdbinst.cfg /mnt/resource/sapbits/hdbinst-local.cfg
sed -i -e $sedcmd -e $sedcmd2 -e $sedcmd3 -e $sedcmd4 -e $sedcmd5 -e $sedcmd6 /mnt/resource/sapbits/hdbinst-local.cfg
echo "hana 1.0 prepare end" >> /tmp/parameter.txt

echo "install hana 1.0 start" >> /tmp/parameter.txt
cd /mnt/resource/sapbits/51052383/DATA_UNITS/HDB_LCM_LINUX_X86_64
/mnt/resource/sapbits/51052383/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /mnt/resource/sapbits/hdbinst-local.cfg
echo "Log file written to '/var/tmp/hdb_H10_hdblcm_install_xxx/hdblcm.log' on host 'saphanaarm'." >> /tmp/parameter.txt
echo "install hana 1.0 end" >> /tmp/parameter.txt


fi
#shutdown -r 1