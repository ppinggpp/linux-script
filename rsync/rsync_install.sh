#!/bin/bash
function Install_Rsync()
{
	yum install wget gcc make automake makeconf openssh*-y
	wget http://down1.chinaunix.net/distfiles/rsync-3.0.4.tar.gz
	tar zxf rsync-3.0.4.tar.gz && cd rsync-3.0.4
	./configure && make && make install
}
function Create_Rsync_Conf()
{
	cat  <<EOF > /etc/rsyncd.conf
uid=nobody
gid=nobody
use chroot=no
max connections=10
strict modes=yes
pid file=/var/run/rsyncd.pid
lock file=/var/run/rsyncd.pid
log file=/var/log/rsyncd.log
[WEBSERVER]
path=/webserver
comment=SHENG file
ignore errors
read only=no
write only=no
hosts allow=xxx.xxx.xxx.xxx
hosts deny=*
auth users=test
secrets file=/etc/rsyncd.pass
EOF
}
which rsync
if [ $? -eq 0 ]
then
	echo  -e "\033[1;32m \033[05m The rsync is Exist! \033[0m"
	Create_Rsync_Conf
	echo -e "\033[1;32m The configure file is /etc/rsyncd.conf \033[0m"
else
	echo -e "\033[1;32m Setup rsync \033[0m"
	Install_Rsync
	echo -e "\033[1;32m Create config file \033[0m"
	Create_Rsync_Conf

	if [ -f /etc/rsyncd.conf ]
	then
		echo -e "\033[1;32m The rsync install OK! \033[0m"
	else
		echo -e "\033[31m \033[05m The rsync install Fail! \033[0m"
	fi
fi
