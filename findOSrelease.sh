#!/bin/bash
######################## DETECTING OS ########################
INFO=$(awk '\
BEGIN {
"getconf LONG_BIT" | getline bitness
OFS=";"
}

$1 == "CentOS" { edistro=tolower($1) ; split($3,centos,".") ; eversion=centos[1]  }

/^ID=/ {
# If we matched ID string, increment so we know it has been detected in input
idm++
# Create array 'a' with whole line ($0), seperated with '='
split($0,a,"=")
# remove quote from name
gsub("\"","",a[2])
distro=a[2]
}

/^VERSION_ID=/ {
# Same as aboe
split($0,a,"=")
gsub("\"","",a[2])
# If we created array b from a[2] with values seperated by ".", set version first member of b array, otherwise set version to a[2] ( no dots in versions)
( split(a[2],b,".") )  ? version=b[1] : version=a[2]
}

END {
# If we detected ID in input, we print centos 6, otherwise we print other detected OS-es
print ( idm > 0  ) ? distro OFS version OFS bitness : edistro OFS eversion OFS bitness
} ' /etc/*-release)

TMPVAR=${INFO%;*}
BITNESS="${INFO##*;}"
NAME="${TMPVAR%;*}"
VERSION="${TMPVAR#*;}"

######################## INSTALLING ZABBIX AGENT ########################
#echo $NAME $VERSION $BITNESS
sudo mkdir -p /mnt/iso
sudo mount -t iso9660 /dev/sr0 /mnt/iso/
case $NAME in
    centos)
        if [ "$VERSION" == "7" ]; then
            rpm -ivh /mnt/iso/rhel7/64/zabbix-agent-4017.rpm
        else
            if [ "$BITNESS" == "64" ]; then
                rpm -ivh /mnt/iso/rhel6/64/zabbix-agent-4017.rpm
            else
                rpm -ivh /mnt/iso/rhel6/32/zabbix-agent-4017.rpm
            fi 
        fi
    ;;

    ubuntu)
        if [ "$VERSION" == "16" ]; then
            if [ "$BITNESS" == "64" ]; then
                sudo dpkg -i /mnt/iso/ubunut/16/64/zabbix-agent.deb
            else
                sudo dpkg -i /mnt/iso/ubuntu/16/32/zabbix-agent.deb
            fi
        else
            if [ "$BITNESS" == "64" ]; then
                sudo dpkg -i /mnt/iso/ubuntu/14/64/zabbix-agent.deb
            else
                sudo dpkg -i /mnt/iso/ubuntu/14/32/zabbix-agent.deb
            fi 
        fi
    ;;
    debian)
            if [ "$BITNESS" == "64" ]; then
                sudo dpkg -i /mnt/iso/debian7/64/zabbix-agent.deb
            else
                sudo dpkg -i /mnt/iso/debian7/32/zabbix-agent.deb
            fi
    ;;
    *)
        printf "%s\n" "Unable to detect exact version, abort" > /tmp/error.txt
        exit 1
    ;;
    esac

######################## CONFIGURING ZABBIX AGENT ########################
kom=$(sed -i "s/Server=127.0.0.1/Server=10.240.35.2/g; s/ServerActive=127.0.0.1/ServerActive=10.240.35.2/g; s/Hostname=Zabbix server/Hostname=$(hostname -f)/g"  /etc/zabbix/zabbix_agentd.conf)
$kom
service zabbix-agent start; chkconfig zabbix-agent on
service zabbix-agent status >> /tmp/zabbixstatus.txt