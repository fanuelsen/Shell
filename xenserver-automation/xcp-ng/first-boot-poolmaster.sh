#!/bin/bash
# Script for setting up Poolmaster in Pool #1 ()
# Wait before start
sleep 60

# Misc. Variables
HTTPD=""                                
XE="/usr/bin/xe"
UUID="$(uuidgen)"
POOLUUID="$(xe pool-list --minimal)"
POOLMASTER_HOSTNAME=""
POOLMASTER_IP=""
POOLMASTER_USERNAME="root"                                             
POOLMASTER_PASSWORD="pleasechangeme"

# Variables for AD user if joining pool to domain.
AD_USER=""
AD_USER_PASS=""
AD_FQDN=""
AD_OBJECT_1=""
AD_OBJECT_2=""

# Make hostname and host-uuid variables
HOSTNAME="$(hostname)"
HOST_UUID="$(xe host-list name-label=${HOSTNAME} --minimal)"

# Storage Network IPs
STORAGE_IP=""
STORAGE_GW=""
STORAGE_MASK=""

# ISO Repository config.
ISO_REP_NAME="ISOREP"
ISO_REP_LOCATION="//myisorep.domain.com/isorep$"

# NFS Repository config.
NFS_REP_NAME="sharednfsstorage"
NFS_REP_UUID=""
NFS_REP_SERVER="0.0.0.0"
NFS_REP_PATH="/data"

# Get the management pif UUID which gets us the IP address and make variables.
MGMT_PIF_UUID=$(xe pif-list params=uuid management=true host-name-label=${HOSTNAME} --minimal)
MGMT_IP=$(xe pif-param-list uuid=${MGMT_PIF_UUID}| grep 'IP '| sed 's/.*: ([0-9.]*)/1/p' | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")

# From the IP address, get the host
HOST=$(echo "${MGMT_IP}" | awk -F: '{ split($1,a,"."); printf ("%d", a[4]); }')

# XVA VM Template
VM_TEMPLATE_01="tstmp"

# VM Names 
VM_NAME_00="CTX01"
VM_NAME_01="CTX02"

# VM MAC Addresses 
VM_MAC_ADDRESS_00="00:00:00:00:00:00"
VM_MAC_ADDRESS_01="00:00:00:00:00:00"


if [ "$HOSTNAME" = $POOLMASTER_HOSTNAME ]; then
    #Network Setup
    TRUNK_PIF_UUID=$(xe pif-list device=eth0 VLAN=-1 --minimal)
    VLAN1000=$(xe network-create name-label="Storage Network")
    VLAN1001=$(xe network-create name-label=VLAN1001)

    # Create VLANS
    xe vlan-create network-uuid=${VLAN1000} pif-uuid=${TRUNK_PIF_UUID} vlan=1000 
    xe vlan-create network-uuid=${VLAN1001} pif-uuid=${TRUNK_PIF_UUID} vlan=1001

    # Configure Storage Network
    VLAN1000_PIF_UUID=$(xe network-list uuid=${VLAN1000} params=PIF-uuids --minimal)
    xe pif-reconfigure-ip mode=static uuid=${VLAN1000_PIF_UUID} ip=$STORAGE_IP.$HOST gateway=$STORAGE_GW netmask=$STORAGE_MASK
    xe pif-param-set other-config:management_purpose="Storage" uuid=${VLAN1000_PIF_UUID}

    # Create resource pool
    xe pool-param-set name-label=MySuperPool uuid="${POOLUUID}"

    # Join Pool to Active Directory
    xe pool-enable-external-auth auth-type=AD service-name="${AD_FQDN}" config:user="${AD_USER}" config:pass="${AD_USER_PASS}"
    xe subject-add subject-name="${AD_OBJECT_1}"
    xe subject-add subject-name="${AD_OBJECT_2}"
    
    # Attatch CIFS ISO Repository
    xe sr-create content-type=iso type=iso shared=true device-config:location="${ISO_REP_LOCATION}" device-config:username="${AD_USER}" device-config:cifspassword="${AD_USER_PASS}" device-config:type=cifs device-config:vers=3.0 name-label=${ISO_REP_NAME}
    
    # Attatch and existing NFS Repository
    xe sr-introduce content-type="NFS" name-label="${NFS_REP_NAME}" uuid="${NFS_REP_UUID}" shared=true type=nfs
    PBD_UUID=$(xe pbd-create sr-uuid="${NFS_REP_UUID}" host-uuid="${HOST_UUID}" device-config:server="${NFS_REP_SERVER}"  device-config:serverpath="${NFS_REP_PATH}")
    xe pbd-plug uuid="$PBD_UUID" host-uuid="$HOST_UUID"
    sleep 10

    # Delete old writechache disks
    DISK_UUID=$(xe vdi-list sr-uuid=${NFS_REP_UUID} params=uuid managed=true --minimal)
    export IFS=","
    for disk in $DISK_UUID; do
        xe vdi-destroy uuid=$disk
    done
    
    # Download Template
    wget "${HTTPD}/xcp-ng/files/${VM_TEMPLATE_01}.xva"

    # Import Templates
    xe vm-import sr-uuid="${NFS_REP_UUID}" filename="${VM_TEMPLATE_01}.xva"
    rm -rf *.xva

    # Create VMs
    VM_UUID=$(xe vm-install template="${VM_TEMPLATE_01}" new-name-label="${VM_NAME_00}")
    VIF_TO_DELETE=$(xe vif-list vm-uuid="${VM_UUID}" | grep '^uuid' | tr -s " " " " | cut -d":" -f2 | cut -d" " -f2)
    xe vif-destroy uuid="${VIF_TO_DELETE}"
    xe vif-create device=0 network-uuid=${VLAN1001} vm-uuid=${VM_UUID} device=0 mac=${VM_MAC_ADDRESS_00}

    VM_UUID=$(xe vm-install template="${VM_TEMPLATE_01}" new-name-label="${VM_NAME_01}")
    VIF_TO_DELETE=$(xe vif-list vm-uuid="${VM_UUID}" | grep '^uuid' | tr -s " " " " | cut -d":" -f2 | cut -d" " -f2)
    xe vif-destroy uuid="${VIF_TO_DELETE}"
    xe vif-create device=0 network-uuid=${VLAN1001} vm-uuid=${VM_UUID} device=0 mac=${VM_MAC_ADDRESS_01}

else

    # Join Pool to Active Directory
    sleep 30
    xe pool-enable-external-auth auth-type=AD service-name="${AD_FQDN}" config:user="${AD_USER}" config:pass="${AD_USER_PASS}"
    
    xe pool-join master-address="${POOLMASTER_IP}" master-username="${POOLMASTER_USERNAME}" master-password="${POOLMASTER_PASSWORD}"
    
    sleep 30

    # Configure Storage Network
    VLAN1000_PIF_UUID=$(xe pif-list params=uuid VLAN=1000 host-name-label=$HOSTNAME --minimal)
    xe pif-reconfigure-ip mode=static uuid=${VLAN1000_PIF_UUID} ip=$STORAGE_IP.$HOST gateway=$STORAGE_GW netmask=$STORAGE_MASK
    xe pif-param-set other-config:management_purpose="Storage" uuid=${VLAN1000_PIF_UUID}
fi

# Disable first boot script for subsequent reboots
rm -rf /etc/systemd/system/postinstall.service

# Remove first boot script
rm -rf /root/first-boot-script.sh

# Indicates that first-boot-script has executed
touch /root/first-boot-executed
if [ ! -f first-boot-executed ]; then
    HOSTSTATE="First boot executed."
    curl -H "Content-Type: application/json" -d "{\"title\": \"$HOSTNAME\", \"text\": \"Host: $HOSTNAME\n\n\nState: $HOSTSTATE\n\n\n\n\n\", \"themeColor\": \"00FF00\"}" # URL to Webhook here
fi

# Final Reboot
reboot
