#!/bin/sh
# Edit the location of your first-boot-script.sh
touch $1/root/post-executed 
wget http://0.0.0.0/first-boot-script.sh   -O $1/root/first-boot-script.sh 
chmod 777 $1/root/first-boot-script.sh
touch $1/etc/systemd/system/postinstall.service
chmod 777 $1/etc/systemd/system/postinstall.service
cat > $1/etc/systemd/system/postinstall.service <<EOF 
[Unit]
After=xapi.service
	 
[Service]
ExecStart=/root/first-boot-script.sh
TimeoutStartSec=infinity
Type=simple		 

[Install]
WantedBy=multi-user.target
EOF
ln -s /etc/systemd/system/postinstall.service $1/etc/systemd/system/multi-user.target.wants/postinstall.service
