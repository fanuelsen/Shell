#!/bin/bash
# Script for setting up Poolmaster
# This is based on this article https://xenserver.org/blog/entry/how-to-installing-xenserver-at-scale.html
# Wait before start
sleep 60

# Variable for http repository
HTTPD=$"http://0.0.0.0/"

# Variable for your XenServer root user
ROOT=$(root)
PASS=$(password)

# Get current hostname which then gets us the host-uuid
HOSTNAME=$(hostname)
HOSTUUID=$(xe host-list name-label=$HOSTNAME --minimal)
 
# Get the management pif UUID which gets us the IP address
MGMTPIFUUID=$(xe pif-list params=uuid management=true host-name-label=$HOSTNAME --minimal)
MGMTIP=$(xe pif-param-list uuid=$MGMTPIFUUID | grep 'IP '| sed 's/.*: ([0-9.]*)/1/p' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# Get the Pool UUID
POOLUUID=$(xe pool-list --minimal)
 
# From the IP address, get the zone and host
ZONE=$(echo "$MGMTIP" | awk -F: '{ split($1,a,"."); printf ("%d", a[3]); }')
HOST=$(echo "$MGMTIP" | awk -F: '{ split($1,a,"."); printf ("%d", a[4]); }')
 
# Assign License to server (select your liscense desktop,free,enterprise-per-socekt etc...)
xe host-apply-edition edition=desktop host-uuid=$HOSTUUID license-server-address=mylisenceserver license-server-port=27000

# Set Control Domain Memory higher for PVS accelerator (If you need more memory or else you can comment out this)
/opt/xensource/libexec/xen-cmdline --set-xen dom0_mem=16384M,max:16384M
 
# Download & Install nVidia GRID Drivers then clean up (comment out this if you dont use Grid)
wget "$HTTPD"NVIDIA-vGPU-kepler-xenserver-7.1-367.106.x86_64.rpm
rpm -i NVIDIA-vGPU-kepler-xenserver-7.1-367.106.x86_64.rpm
rm -rf NVIDIA-vGPU-kepler-xenserver-7.1-367.106.x86_64.rpm

# Download and install Xenserver Patch & Supplemental Packs
#01
wget "$HTTPD"XS71E001.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E001.iso
xe update-pool-apply uuid=fc438a32-0214-4193-8676-9feb121c6997
rm -rf XS71E001.iso
#05
wget "$HTTPD"xenserver/patch/71/XS71E005.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E005.iso
xe update-pool-apply uuid=d2df0c4f-eaf6-4778-a754-19a8b7739b5c
rm -rf XS71E005.iso
#09
wget "$HTTPD"XS71E009.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E009.iso
xe update-pool-apply uuid=bd86763b-beb0-4fec-97e1-fe0735f48620
rm -rf XS71E009.iso
#10
wget "$HTTPD"XS71E010.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E010.iso
xe update-pool-apply uuid=c55e30a5-a02d-4e4c-935c-4d6802721d40
rm -rf XS71E010.iso
#13
wget "$HTTPD"XS71E013.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E013.iso
xe update-pool-apply uuid=927031d5-fdab-4bc1-9a56-704e7d9a8485
rm -rf XS71E013.iso
#14
wget "$HTTPD"XS71E014.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XS71E014.iso
xe update-pool-apply uuid=2d841bf6-e799-479b-a19a-9a23b241c973
rm -rf XS71E014.iso

#PVSaccelerator (Installs supplementalpack this can be commented out)
wget "$HTTPD"XenServer-7.1.0-pvsaccelerator.iso
xe -s $HOSTNAME -u $ROOT -pw $PASS update-upload file-name=XenServer-7.1.0-pvsaccelerator.iso
xe update-pool-apply uuid=9b2b855c-469b-41df-9eff-797e00bd2b1e
rm -rf XenServer-7.1.0-pvsaccelerator.iso

# Fixes PML issue if you have more than 512GB of ram or VGPU and broadwell (or newer). Random reboots my occoure if this is not entered. https://support.citrix.com/article/CTX220674
/opt/xensource/libexec/xen-cmdline --set-xen ept=no-pml
/opt/xensource/libexec/xen-cmdline --set-xen iommu=dom0-passthrough

# Restart Tool-Stack
xe-restart-toolstack
sleep 10

# Create Network (Modify this to your own)
VLAN=$(xe network-create name-label="Virtual Machine Network")
ETH0=$(xe pif-list device=eth0 --minimal)
xe vlan-create network-uuid=$VLAN pif-uuid=$ETH0 vlan=1000
xe network-param-set uuid=$VLAN MTU=9000

# Setup storage network. For us, that’s on eth0. the ip needs to be configured (if you have many hosts the $HOST variable is dynamic in terms that it uses the same ending as your interface ip)
STORAGEPIFUUID=$(xe pif-list params=uuid VLAN=1000 --minimal)
xe pif-reconfigure-ip mode=static uuid=$STORAGEPIFUUID ip=0.0.0.$HOST gateway=0.0.0.0 netmask=255.255.255.0
xe pif-param-set disallow-unplug=true uuid=$STORAGEPIFUUID
xe pif-param-set other-config:management_purpose="Storage" uuid=$STORAGEPIFUUID

# Reatch NFS Storage (Device-config:server is the ip to your NFS storage)
SRUUID=$(uuidgen)
xe sr-introduce content-type="NFS" name-label="pleasechangeme" uuid=$SRUUDID shared=true type=nfs
PBDUUID=$(xe pbd-create sr-uuid=$SRUUID host-uuid=$HOSTUUID device-config:server=0.0.0.0 device-config:serverpath=/WriteCache)
xe pbd-plug uuid=$PBDUUID host-uuid=$HOSTUUID

# Attatch CIFS ISO Repository (Enter username and password)

OPTIONS="-o username=pleasechangeme,password=pleasechangeme,cache=none"
XE="/usr/bin/xe"
ISOUUID=$(uuidgen)
LOCATION="//myfileserver/isorep$"
SR=$(${XE} sr-introduce name-label="ISOREP" content-type=iso shared=true type=iso uuid=$ISOUUID physical-size=0)
${XE} sr-param-set other-config:auto-scan=true uuid=$ISOUUID

PBD=$(${XE} pbd-create host-uuid=${HOSTUUID} sr-uuid=$SR device-config:location="${LOCATION}" device-config:options="${OPTIONS}")
xe pbd-plug uuid=${PBD}

# Install Windows 10 Template (downloads vm template from http repo, this is for simpler deployment of vms later with PVS)
wget "$HTTPD"Windows10template.xva
xe vm-import sr-uuid=$SRUUID filename=Windows10template.xva
rm -rf Windows10template.xva

# Create resource pool
xe pool-param-set name-label=MYPOOLNAME uuid=$POOLUUID

# Disable first boot script for subsequent reboots
rm -rf /etc/systemd/system/postinstall.service

# Remove first boot script
rm -rf /root/first-boot-script.sh

# Indicates that first-boot-script has executed
touch /root/first-boot-executed

# Final Reboot
reboot
