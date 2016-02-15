#!/bin/bash
#Author: zeping

#需要自行修改rsyncd.conf配置文件和添加rsyncd.pass文件

function install_Rsync(){
    yum install rsync -y
    if [ $? -ne 0 ];then
        cd $Download_dir
    	yum install wget gcc make automake makeconf openssh*-y
    	wget http://down1.chinaunix.net/distfiles/rsync-3.0.4.tar.gz -P
    	tar zxf rsync-3.0.4.tar.gz && cd rsync-3.0.4
    	./configure && make && make install
    fi

}

function create_Rsync_Conf(){
	cat  > /etc/rsyncd.conf<<EOF
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

function create_Rsyncd_Command(){
    cat >/etc/init.d/rsyncd<<EOF
#!/bin/bash
Rsync_Command=`whereis rsync | awk '{print $2}'`
function Start()
{
    ${Rsync_Command} --daemon
    if [ $? -eq 0 ]
        then
            echo -e "\033[1;32m  The rsyncd start successful...... \033[0m"
        else
            echo -e "\033[31m \033[05m The rsyncd start fail !!!!!!!! \033[0m"
    fi
}
function Stop()
{
    if [ -f '/var/run/rsyncd.pid' ]
        then
            kill -9 `cat /var/run/rsyncd.pid`
            sleep 1
            proce_num=`ps -ef | grep ${Rsync_Command} | grep -v grep | wc -l`
            if [ ${proce_num} -gt 0 ]
                then
                    echo -e "\033[31m \033[05m The rsyncd Stop fail !!!!!!!! \033[0m"
                else
                    echo -e "\033[1;32m  The rsyncd Stop successful...... \033[0m"
                    rm /var/run/rsyncd.pid
            fi
    else
        echo -e "\033[31m \033[05m  The /var/run/rsyncd.pid file is not exist! Check rsync is Runing ??? \033[0m"

    fi
}
function Restart()
{
    Stop
    sleep 2
    Start
}
case $1 in
    start)
        Start
        ;;
    stop)
        Stop
        ;;
    restart)
        Restart
        ;;
    *)
        echo -e "\033[31m \033[05m Use start|stop|restart \033[0m"
        ;;
esac
EOF
chown 755 /etc/init.d/rsyncd
}

function main(){

    Download_dir=/data/soft
	if [ ! -d $Download_dir ];then
		mkdir -p $Download_dir
	fi
	Install_dir=/data/local
	if [ ! -d $Install_dir ];then
		mkdir -p $Install_dir
	fi

    which rsync
    if [ $? -eq 0 ];then
    	echo  -e "\033[1;32m \033[05m The rsync is Exist! \033[0m"
    	Create_Rsync_Conf
    	echo -e "\033[1;32m The configure file is /etc/rsyncd.conf \033[0m"
        create_Rsyncd_Command

    else
    	echo -e "\033[1;32m Setup rsync \033[0m"
    	Install_Rsync
    	echo -e "\033[1;32m Create config file \033[0m"
    	Create_Rsync_Conf
        create_Rsyncd_Command
    fi
}
