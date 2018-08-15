#!/bin/bash
set -x
# store arguments in a special array
args=("$@")
# get number of elements
ELEMENTS=${#args[@]}

# echo each element in array
# for loop
for (( i=0;i<$ELEMENTS;i++)); do
    echo ${args[${i}]}
done

URI=$1
shift
HANAUSR=$1
shift
HANAPWD=$1
shift
HANASID=$1
shift
HANANUMBER=$1
shift
VMNAME=$1
shift
OTHERVMNAME=$1
shift
VMIPADDR=$1
shift
OTHERIPADDR=$1
shift
CONFIGHSR=$1
shift
ISPRIMARY=$1
shift
REPOURI=$1
shift
ISCSIIP=$1
shift
LBIP=$1
shift
SUBEMAIL=$1
shift
SUBID=$1
shift
SUBURL=$1

#get the VM size via the instance api
VMSIZE=`curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/vmSize?api-version=2017-08-01&format=text"`


HANASIDU="${HANASID^^}"
HANASIDL="${HANASID,,}"

HANAADMIN="$HANASIDL"adm
echo "HANAADMIN:" $HANAADMIN >>/tmp/variables.txt

echo "small.sh receiving:"
echo "URI:" $URI >> /tmp/variables.txt
echo "HANAUSR:" $HANAUSR >> /tmp/variables.txt
echo "HANAPWD:" $HANAPWD >> /tmp/variables.txt
echo "HANASID:" $HANASID >> /tmp/variables.txt
echo "HANANUMBER:" $HANANUMBER >> /tmp/variables.txt
echo "VMSIZE:" $VMSIZE >> /tmp/variables.txt
echo "VMNAME:" $VMNAME >> /tmp/variables.txt
echo "OTHERVMNAME:" $OTHERVMNAME >> /tmp/variables.txt
echo "VMIPADDR:" $VMIPADDR >> /tmp/variables.txt
echo "OTHERIPADDR:" $OTHERIPADDR >> /tmp/variables.txt
echo "CONFIGHSR:" $CONFIGHSR >> /tmp/variables.txt
echo "ISPRIMARY:" $ISPRIMARY >> /tmp/variables.txt
echo "REPOURI:" $REPOURI >> /tmp/variables.txt
echo "ISCSIIP:" $ISCSIIP >> /tmp/variables.txt
echo "LBIP:" $LBIP >> /tmp/variables.txt
echo "SUBEMAIL:" $SUBEMAIL >> /tmp/variables.txt
echo "SUBID:" $SUBID >> /tmp/variables.txt
echo "SUBURL:" $SUBURL >> /tmp/variables.txt

#if needed, register the machine
if [ "$SUBEMAIL" != "" ]; then
  if [ "$SUBURL" != "" ]; then 
   SUSEConnect -e $SUBEMAIL -r $SUBID --url $SUBURL
  else 
   SUSEConnect -e $SUBEMAIL -r $SUBID
  fi
fi


mkdir /etc/systemd/login.conf.d
mkdir /hana
mkdir /hana/data
mkdir /hana/log
mkdir /hana/shared
mkdir /hana/backup
mkdir /usr/sap

number="$(lsscsi [*] 0 0 4| cut -c2)"
if [ $VMSIZE == "Standard_E16s_v3" ] || [ "$VMSIZE" == "Standard_E32s_v3" ] || [ "$VMSIZE" == "Standard_E64s_v3" ] || [ "$VMSIZE" == "Standard_GS5" ] ; then
echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt

#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  pvcreate $backupvglun $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt
fi

if [ $VMSIZE == "Standard_M64s" ]; then
echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 5 | grep -o '.\{9\}$')"
  pvcreate hanavg $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun1="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  backupvglun2="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  pvcreate $backupvglun1 $backupvglun2 $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun1 $backupvglun2
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt
fi

if [ $VMSIZE == "Standard_M64ms" ] || [ $VMSIZE == "Standard_M128s" ]; then
echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 5 | grep -o '.\{9\}$')"
  hanavg3lun="$(lsscsi $number 0 0 6 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun $hanavg3lun
  vgcreate hanavg $hanavg1lun $hanavg2lun $hanavg3lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun1="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  backupvglun2="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  pvcreate $backupvglun1 $backupvglun2 $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun1 $backupvglun2
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt
fi

if [ $VMSIZE == "Standard_M128ms" ]; then
echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 7 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 8 | grep -o '.\{9\}$')"
  hanavg3lun="$(lsscsi $number 0 0 9 | grep -o '.\{9\}$')"
  hanavg4lun="$(lsscsi $number 0 0 10 | grep -o '.\{9\}$')"
  hanavg5lun="$(lsscsi $number 0 0 11 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun $hanavg3lun $hanavg4lun $hanavg5lun
  vgcreate hanavg $hanavg1lun $hanavg2lun $hanavg3lun $hanavg4lun $hanavg5lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun1="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  backupvglun2="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  backupvglun3="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  backupvglun4="$(lsscsi $number 0 0 5 | grep -o '.\{9\}$')"
  backupvglun5="$(lsscsi $number 0 0 6 | grep -o '.\{9\}$')"
  pvcreate $backupvglun1 $backupvglun2 $backupvglun3 $backupvglun4 $backupvglun5 $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun1 $backupvglun2 $backupvglun3 $backupvglun4 $backupvglun5
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt
fi
#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mkdir /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt

echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/hanavg-datalv /hana/data xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/hanavg-loglv /hana/log xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv /hana/shared xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv /hana/backup xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

if [ ! -d "/hana/data/sapbits" ]
 then
 mkdir "/hana/data/sapbits"
fi

write_corosync_config (){
  BINDIP=$1
  HOST1IP=$2
  HOST2IP=$3
  mv /etc/corosync/corosync.conf /etc/corosync/corosync.conf.orig 
cat > /etc/corosync/corosync.conf <<EOF
totem {
        version:        2
        secauth:        on
        crypto_hash:    sha1
        crypto_cipher:  aes256
        cluster_name:   hacluster
        clear_node_high_bit: yes
        token:          5000
        token_retransmits_before_loss_const: 10
        join:           60
        consensus:      6000
        max_messages:   20
        interface {
                ringnumber:     0
                bindnetaddr:    $BINDIP
                mcastport:      5405
                ttl:            1
        }
 transport:      udpu
}
nodelist {
  node {
   ring0_addr:$HOST1IP
   nodeid:1
  }
  node {
   ring0_addr:$HOST2IP
   nodeid:2
  }
  transport:      udpu
}

logging {
        fileline:       off
        to_stderr:      no
        to_logfile:     no
        logfile:        /var/log/cluster/corosync.log
        to_syslog:      yes
        debug:          off
        timestamp:      on
        logger_subsys {
                subsys: QUORUM
                debug:  off
        }
}
quorum {
        # Enable and configure quorum subsystem (default: off)
        # see also corosync.conf.5 and votequorum.5
        provider: corosync_votequorum
        expected_votes: 2
        two_node: 1
}
EOF

}



#install hana prereqs
zypper install -y glibc-2.22-51.6
zypper install -y systemd-228-142.1
zypper install -y unrar
zypper in -t pattern -y sap-hana
#zypper install -y sapconf
zypper install -y saptune
zypper install -y libunwind
zypper install -y libicu

sudo saptune solution apply HANA
saptune daemon start

# step2
echo $URI >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf
# we may be able to restart the waagent and get the swap configured immediately

cat >>/etc/hosts <<EOF
$VMIPADDR $VMNAME
$OTHERIPADDR $OTHERVMNAME
EOF

#!/bin/bash
cd /hana/data/sapbits
echo "hana download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $URI/SapBits/md5sums
/usr/bin/wget --quiet $URI/SapBits/51053061_part1.exe
/usr/bin/wget --quiet $URI/SapBits/51053061_part2.rar
/usr/bin/wget --quiet $URI/SapBits/51053061_part3.rar
/usr/bin/wget --quiet $URI/SapBits/51053061_part4.rar
/usr/bin/wget --quiet "https://raw.githubusercontent.com/AzureCAT-GSI/SAP-HANA-ARM/master/hdbinst.cfg"
echo "hana download end" >> /tmp/parameter.txt

date >> /tmp/testdate
cd /hana/data/sapbits

echo "hana unrar start" >> /tmp/parameter.txt
#!/bin/bash
cd /hana/data/sapbits
unrar x 51053061_part1.exe
echo "hana unrar end" >> /tmp/parameter.txt

echo "hana prepare start" >> /tmp/parameter.txt
cd /hana/data/sapbits

#!/bin/bash
cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/root_password=AweS0me@PW/root_password=$HANAPWD/g"
sedcmd5="s/master_password=AweS0me@PW/master_password=$HANAPWD/g"
sedcmd6="s/sid=H10/sid=$HANASID/g"
sedcmd7="s/number=00/number=$HANANUMBER/g"
cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
echo "hana preapre end" >> /tmp/parameter.txt

##change this to pass passwords on command line

#!/bin/bash
echo "install hana start" >> /tmp/parameter.txt
cd /hana/data/sapbits/51053061/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51053061/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
echo "install hana end" >> /tmp/parameter.txt
echo "install hana end" >> /tmp/hanacomplete.txt

##external dependency on sshpt
    zypper install -y python-pip
    pip install sshpt
    #set up passwordless ssh on both sides
    cd ~/
    #rm -r -f .ssh
    cat /dev/zero |ssh-keygen -q -N "" > /dev/null

    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "mkdir -p /root/.ssh"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo -c ~/.ssh/id_rsa.pub -d /root/
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "cp /root/id_rsa.pub /root/.ssh/authorized_keys"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chown root:root /root/.ssh/authorized_keys"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh/authorized_keys"
    
#
if [ "$CONFIGHSR" == "yes" ]; then
    echo "hsr config start" >> /tmp/parameter.txt	    
    HANASIDU="${HANASID^^}"

    cd /root
    wget $REPOURI/scripts/waitfor.sh
    chmod u+x waitfor.sh
    SYNCUSER="hsrsync"
    SYNCPASSWORD="Repl1cate"

 ##get rid of user creation, was only needed in hana 1.0   
 ##remove the "initial backup" because it's redundant
    cat >/tmp/hdbsetupsql <<EOF
CREATE USER $SYNCUSER PASSWORD $SYNCPASSWORD;
grant data admin to $SYNCUSER;
ALTER USER $SYNCUSER DISABLE PASSWORD LIFETIME;
backup data using file ('initial backup'); 
BACKUP DATA for $HANASID USING FILE ('backup');
BACKUP DATA for SYSTEMDB USING FILE ('SYSTEMDB backup');
EOF


chmod a+r /tmp/hdbsetupsql
su - -c "hdbsql -u system -p $HANAPWD -d SYSTEMDB -I /tmp/hdbsetupsql" $HANAADMIN 
touch /tmp/hanabackupdone.txt
./waitfor.sh root $OTHERVMNAME /tmp/hanabackupdone.txt

    
if [ "$ISPRIMARY" = "yes" ]; then
	echo "hsr primary start" >> /tmp/parameter.txt	

	#now set the role on the primary
	cat >/tmp/srenable <<EOF
hdbnsutil -sr_enable --name=system0 	
EOF
	chmod a+r /tmp/srenable
	su - $HANAADMIN -c "bash /tmp/srenable"

	touch /tmp/readyforsecondary.txt
	./waitfor.sh root $OTHERVMNAME /tmp/readyforcerts.txt	
	scp /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT root@$OTHERVMNAME:/root/SSFS_$HANASIDU.DAT
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "cp /root/SSFS_$HANASIDU.DAT /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT"
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "chown $HANAADMIN:sapsys /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT"

	scp /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY root@$OTHERVMNAME:/root/SSFS_$HANASIDU.KEY
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "cp /root/SSFS_$HANASIDU.KEY /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY"
	ssh -o BatchMode=yes  -o StrictHostKeyChecking=no root@$OTHERVMNAME "chown $HANAADMIN:sapsys /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY"

	touch /tmp/dohsrjoin.txt
    else
	#do stuff on the secondary
	./waitfor.sh root $OTHERVMNAME /tmp/readyforsecondary.txt	

	touch /tmp/readyforcerts.txt
	./waitfor.sh root $OTHERVMNAME /tmp/dohsrjoin.txt	
	cat >/tmp/hsrjoin <<EOF
sapcontrol -nr $HANANUMBER -function StopSystem HDB
sapcontrol -nr $HANANUMBER -function WaitforStopped 600 2
hdbnsutil -sr_register --name=system1 --remoteHost=$OTHERVMNAME --remoteInstance=$HANANUMBER --replicationMode=sync --operationMode=logreplay
sapcontrol -nr $HANANUMBER -function StartSystem HDB
EOF

	chmod a+r /tmp/hsrjoin
	su - $HANAADMIN -c "bash /tmp/hsrjoin"
    fi
fi

#Clustering setup
#start services [A]
systemctl enable iscsid
systemctl enable iscsi
systemctl enable sbd

#set up iscsi initiator [A]
myhost=`hostname`
cp -f /etc/iscsi/initiatorname.iscsi /etc/iscsi/initiatorname.iscsi.orig
#change the IQN to the iscsi server
sed -i "/InitiatorName=/d" "/etc/iscsi/initiatorname.iscsi"
echo "InitiatorName=iqn.1991-05.com.microsoft:hanajb-hsrtarget-target:$myhost" >> /etc/iscsi/initiatorname.iscsi
systemctl restart iscsid
systemctl restart iscsi
iscsiadm -m discovery --type=st --portal=$ISCSIIP


iscsiadm -m node -T iqn.1991-05.com.microsoft:hanajb-hsrtarget-target --login --portal=$ISCSIIP:3260
iscsiadm -m node -p $ISCSIIP:3260 --op=update --name=node.startup --value=automatic

#node1
if [ "$ISPRIMARY" = "yes" ]; then

sleep 10 
echo "hana iscsi end" >> /tmp/parameter.txt

device="$(lsscsi 6 0 0 0| cut -c59-)"
diskid="$(ls -l /dev/disk/by-id/scsi-* | grep $device)"
sbdid="$(echo $diskid | grep -o -P '/dev/disk/by-id/scsi-3.{32}')"
sbd -d $sbdid -1 90 -4 180 create
else

echo "hana iscsi end" >> /tmp/parameter.txt
sleep 10 
fi

#!/bin/bash [A]
cd /etc/sysconfig
cp -f /etc/sysconfig/sbd /etc/sysconfig/sbd.new
device="$(lsscsi 6 0 0 0| cut -c59-)"
diskid="$(ls -l /dev/disk/by-id/scsi-* | grep $device)"
sbdid="$(echo $diskid | grep -o -P '/dev/disk/by-id/scsi-3.{32}')"
sbdcmd="s#SBD_DEVICE=\"\"#SBD_DEVICE=\"$sbdid\"#g"
sbdcmd2='s/SBD_PACEMAKER=/SBD_PACEMAKER="yes"/g'
sbdcmd3='s/SBD_STARTMODE=/SBD_STARTMODE="always"/g'
cat sbd.new | sed $sbdcmd | sed $sbdcmd2 | sed $sbdcmd3 > sbd.modified
cp -f /etc/sysconfig/sbd.modified /etc/sysconfig/sbd
echo "hana sbd end" >> /tmp/parameter.txt

echo softdog > /etc/modules-load.d/softdog.conf
modprobe -v softdog
echo "hana watchdog end" >> /tmp/parameter.txt
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

#node1
if [ "$ISPRIMARY" = "yes" ]; then
ha-cluster-init -y -q sbd -d $sbdid
ha-cluster-init -y -q csync2
ha-cluster-init -y -q -u corosync

ha-cluster-init -y -q cluster name=hanacluster interface=eth0
cd /etc/corosync
write_corosync_config 10.0.5.0 $VMIPADDR $OTHERIPADDR
systemctl restart corosync

sleep 10

cd /tmp
#configure SAP HANA topology
HANAID="$HANASID"_HDB"$HANANUMBER"

sudo crm configure property maintenance-mode=true

crm configure primitive rsc_SAPHanaTopology_$HANAID ocf:suse:SAPHanaTopology \
        operations \$id="rsc_sap2_$HANAID-operations" \
        op monitor interval="10" timeout="600" \
        op start interval="0" timeout="600" \
        op stop interval="0" timeout="300" \
        params SID="$HANASID" InstanceNumber="$HANANUMBER"

crm configure clone cln_SAPHanaTopology_$HANAID rsc_SAPHanaTopology_$HANAID \
        meta clone-node-max="1" interleave="true"

crm configure primitive rsc_SAPHana_$HANAID ocf:suse:SAPHana     \
operations \$id="rsc_sap_$HANAID-operations"   \
op start interval="0" timeout="3600"    \
op stop interval="0" timeout="3600"    \
op promote interval="0" timeout="3600"    \
op monitor interval="60" role="Master" timeout="700"    \
op monitor interval="61" role="Slave" timeout="700"   \
params SID="$HANASID" InstanceNumber="$HANANUMBER" PREFER_SITE_TAKEOVER="true"  \
DUPLICATE_PRIMARY_TIMEOUT="7200" AUTOMATED_REGISTER="false"

crm configure ms msl_SAPHana_$HANAID rsc_SAPHana_$HANAID meta is-managed="true" \
notify="true" clone-max="2" clone-node-max="1" target-role="Started" interleave="true"

crm configure primitive rsc_ip_$HANAID ocf:heartbeat:IPaddr2 \
        operations \$id="rsc_ip_$HANAID-operations" \
        op monitor interval="10s" timeout="20s" \
        params ip="$LBIP"

crm configure primitive rsc_nc_$HANAID anything \
     params binfile="/usr/bin/nc" cmdline_options="-l -k 62503" \
     op monitor timeout=20s interval=10 depth=0

crm configure group g_ip_$HANAID rsc_ip_$HANAID rsc_nc_$HANAID

#crm configure colocation col_saphana_ip_$HANAID 2000: rsc_ip_$HANAID:Started \
#    msl_SAPHana_$HANAID:Master
crm configure colocation col_saphana_ip_$HANAID 2000: rsc_ip_$HANAID:Started  msl_SAPHana_$HANAID:Master

crm configure order ord_SAPHana_$HANAID 2000: cln_SAPHanaTopology_$HANAID  msl_SAPHana_$HANAID

sleep 20

sudo crm resource cleanup rsc_SAPHana_$HANAID

sudo crm configure property maintenance-mode=false

fi
#node2
if [ "$ISPRIMARY" = "no" ]; then
ha-cluster-join -y -q -c $OTHERVMNAME csync2 
ha-cluster-join -y -q ssh_merge
ha-cluster-join -y -q cluster
cd /etc/corosync
write_corosync_config 10.0.5.0 $OTHERIPADDR $VMIPADDR 
systemctl restart corosync
fi


