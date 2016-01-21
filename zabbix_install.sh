#!/bin/bash
#zabbix客户端安装程序脚本
#
function check_File(){
    cd $Download_dir
    wget $1
    if [ $? -ne 0 ];then
        echo -e "\033[47;31m $File_name download fail \033[0m"
    fi
    File_name=`echo $1|awk -F "/" '{print $NF}'`
    if [ -f $File_name ];then
        #tar.gz和tgz后缀
        if [[ $File_name =~ "tar.gz" || $File_name =~ "tgz" ]];then
            tar zxf $File_name
            if [ $? -ne 0 ];then
                echo -e "\033[47;31m $File_name file is Error \033[0m"
                exit 1
            fi
            if [[ $File_name =~ "tar.gz" ]];then
                Dir_name=`basename $File_name .tar.gz`
            else
                Dir_name=`basename $File_name .tgz`
            fi
            cd $Dir_name
        #zip后缀
        elif [[ $File_name =~ "zip" || $File_name =~ "ZIP" ]]; then
            unzip $File_name
            if [ $? -ne 0 ];then
                echo -e "\033[47;31m $File_name file is Error \033[0m"
                exit 1
            fi
            if [[ $File_name =~ "ZIP" ]];then
                Dir_name=`basename $File_name ZIP`
            else
                Dir_name=`basename $File_name zip`
            fi
            cd $Dir_name
        fi
    else
        echo -e "\033[47;31m $File_name file is not Found \033[0m"
        exit 1
    fi
}
function check_Configure(){
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m $(basename `pwd`) configure fail!!!! \033[0m"
		exit 1
	else
		echo -e "\033[42;37m $(basename `pwd`)  configure successful  \033[0m"
	fi
}
function check_Make(){
	echo "$(basename `pwd`) start make......."
	make > /dev/null
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m $(basename `pwd`) make fail!!!! \033[0m"
		exit 1
	else
		echo -e "\033[42;37m $(basename `pwd`)  make successful  \033[0m"
	fi
}
#单独把make install分出来 是为了适应那些不需要这个步骤的软件包 比如redis
function check_Make_Install(){
    echo "$(basename `pwd`) start make install......."
    make install >/dev/null
    if [ $? -ne 0 ];then
        echo -e "\033[47;31m $(basename `pwd`) make install fail!!!! \033[0m"
        exit 1
    else
        echo -e "\033[42;37m $(basename `pwd`)  make install successful  \033[0m"
    fi
}
function zabbix_Agentd_Seting(){
    #zabbix日志目录 和外部脚本
    mkdir /data/local/zabbix/{log,scripts}
    chown -R zabbix.zabbix /data/local/zabbix
    #设置zabbix agentd的配置文件
        #日志文件
    sed -i 's/LogFile=\/tmp\/zabbix_agentd.log/LogFile=\/data\/local\/zabbix\/log\/zabbix_agentd.log/g' /data/local/zabbix/etc/zabbix_agentd.conf
        #区分配置文件
    sed -i 's/^# Include=\/usr\/local\/etc\/zabbix_agentd.conf.d\//Include=\/data\/local\/zabbix\/etc\/zabbix_agentd.conf.d\//g' /data/local/zabbix/etc/zabbix_agentd.conf
        #打开用户自定义key功能
    sed -i 's/^# UnsafeUserParameters=0/UnsafeUserParameters=1/g' /data/local/zabbix/etc/zabbix_agentd.conf
        #设置服务端地址,判断Server_host_ip变量,有就设置成变量值,没有就使用默认的地址
    if [ ! "$Server_host_ip" ];then
        echo "Zabbix server IPAddress is 127.0.0.1"
    else
        sed -i "s/^Server=.*$/Server=${Server_host_ip}/g" /data/local/zabbix/etc/zabbix_agentd.conf
        sed -i "s/^ServerActive=.*$/ServerActive=${Server_host_ip}/g" /data/local/zabbix/etc/zabbix_agentd.conf
    fi
}
function zabbix_Install(){
    groupadd zabbix 2>/dev/null
    useradd -M -s /sbin/nologin -g zabbix zabbix 2>/dev/null
    check_File $Zabbix_package
    if [ "$1"="agent" ];then
        ./configure --prefix=/data/local/zabbix/ --enable-agent
        sed -i 's/BASEDIR=\/usr\/local/BASEDIR=\/data\/local\/zabbix/g' misc/init.d/fedora/core/zabbix_agentd
        cp misc/init.d/fedora/core/zabbix_agentd /etc/init.d/zabbix_agentd
        chmod 755 /etc/init.d/zabbix_agentd
        #创建外部脚本目录
        #mkdir /data/local/zabbix/scripts
    elif [ "$1"="server"];then
        ./configure --prefix=/data/local/zabbix/ \
        --enable-server \
        --enable-agent \
        --with-mysql \
        --with-net-snmp \
        --with-libcurl \
        --with-libxml2
        sed -i 's/BASEDIR=\/usr\/local/BASEDIR=\/data\/local\/zabbix/g' misc/init.d/fedora/core/zabbix*
        cp misc/init.d/fedora/core/zabbix* /etc/init.d/
        chmod 755 /etc/init.d/zabbix*
    fi
    check_Configure
    check_Make
    check_Make_Install
    zabbix_Agentd_Seting
    #创建外部脚本目录
    #mkdir /data/local/zabbix/scripts
}
function nginx_php(){
    PHP_conf_file="/data/local/zabbix/etc/zabbix_agentd.conf.d/php.conf"
    NGX_conf_file="/data/local/zabbix/etc/zabbix_agentd.conf.d/nginx.conf"
    if [ -f $PHP_conf_file ];then
        echo -e "\033[43;37m zabbix php.conf is exist,please check the file.... \330[0m"
    else
            #打开php监控
        if ! grep "/php_status" /data/local/php/etc/php-fpm.conf;then
            #php
            cp /data/local/php/etc/php-fpm.conf /data/local/php/etc/php-fpm.conf.zabbix.before
            echo "pm.status_path=/php_status" >> /data/local/php/etc/php-fpm.conf
            /etc/init.d/php-fpm restart
            echo "UserParameter=php-fpm.status[*],/usr/bin/curl -s 'http://127.0.0.1/php_status?xml' | grep '<\$1>' | awk -F'>|<' '{ print \$\$3}'" > $PHP_conf_file
        fi
    fi
    if [ -f $NGX_conf_file ];then
        echo -e "\033[43;37m zabbix nginx.conf is exist,please check the file.... \330[0m"
    else
        #打开nginx监控
        echo "UserParameter=nginx.status[*],/data/local/zabbix/scripts/ngx-status.sh \$1" > $NGX_conf_file
        cat >/data/local/zabbix/scripts/ngx-status.sh<<eof
#!/bin/bash
# DateTime: 2015-10-25
# AUTHOR：凉白开
# WEBSITE: http://www.ttlsa.com
# Description：zabbix监控nginx性能以及进程状态
# Note：此脚本需要配置在被监控端，否则ping检测将会得到不符合预期的结果
# 文章地址：http://www.ttlsa.com/zabbix/zabbix-monitor-nginx-performance/ ‎
HOST="127.0.0.1"
PORT="80"
# 检测nginx进程是否存在
function ping {
    /sbin/pidof nginx | wc -l
}
# 检测nginx性能
function active {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| grep 'Active' | awk '{print \$NF}'
}
function reading {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| grep 'Reading' | awk '{print \$2}'
}
function writing {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| grep 'Writing' | awk '{print \$4}'
}
function waiting {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| grep 'Waiting' | awk '{print \$6}'
}
function accepts {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| awk NR==3 | awk '{print \$1}'
}
function handled {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| awk NR==3 | awk '{print \$2}'
}
function requests {
    /usr/bin/curl "http://\$HOST:\$PORT/ngx_status/" 2>/dev/null| awk NR==3 | awk '{print \$3}'
}
# 执行function
\$1
eof
        chmod 755 /data/local/zabbix/scripts/ngx-status.sh
    fi
    #打开
    if [ ! -f "/data/local/nginx/conf/vhost/status.conf" ];then
        cat >/data/local/nginx/conf/vhost/status.conf<<eof
server {
    listen  80;
    server_name 127.0.0.1;
    allow 127.0.0.1;
    deny all;
    location /ngx_status
    {
        stub_status on;
        access_log off;
    }
    location /php_status
    {
        include fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_param SCRIPT_FILENAME \$fastcgi_script_name;
        access_log off;
    }
}
eof
        #重新加载nginx配置文件
        /data/local/nginx/sbin/nginx -t
        if [ $? -ne 0 ];then
            echo -e "\033[43;37m nginx status.conf is error \330[0m"
        else
            /data/local/nginx/sbin/nginx -s reload
        fi
        /etc/init.d/zabbix_agentd restart
    fi
}

function memcached(){
    Memcached_conf_file="/data/local/zabbix/etc/zabbix_agentd.conf.d/memcached.conf"
    if [ -f $Memcached_conf_file ];then
        echo -e "\033[43;37m zabbix memcached.conf is exist,please check the file.... \330[0m"
    else
        cat >/data/local/zabbix/scripts/memcache.py<<eof
#!/usr/bin/env python
import telnetlib
import sys
tn = telnetlib.Telnet('127.0.0.1',port=11211,timeout=60)
tn.write('stats\n')
tn.write('quit\n')
tm =  tn.read_all()
print tm
eof
        echo "UserParameter=memcached.status[*],/data/local/zabbix/scripts/memcache.py  | grep '\$1' | awk '{print \$\$3}'" > $PHP_conf_file
        /etc/init.d/zabbix_agentd restart
    fi

}


function Main(){
    Download_dir=/data/soft
	if [ ! -d $Download_dir ];then
		mkdir -p $Download_dir
	fi
	Install_dir=/data/local
	if [ ! -d $Install_dir ];then
		mkdir -p $Install_dir
	fi
    #防止链接失效,以后修改脚本到处找变量  麻烦
    Zabbix_package="http://netix.dl.sourceforge.net/project/zabbix/ZABBIX%20Latest%20Stable/2.2.11/zabbix-2.2.11.tar.gz"
    Server_host_ip=10.10.11.51
    zabbix_Install agent
    nginx_php
}
Main
