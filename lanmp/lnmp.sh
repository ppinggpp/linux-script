#!/bin/bash
#Author: zeping
#
######~~~~~~~~~~~~~~~~~~~工具函数部分~~~~~~~~~~~~~~~~~~~
#工具函数 - 用于检测是否成功下载文件,文件是否存在,解压,自动进入目录
function check_File(){
    if [ -f $1 ];then
        #tar.gz和tgz后缀
        if [[ $1 =~ "tar.gz" || $1 =~ "tgz" ]];then
            tar zxf $1
            if [ $? -ne 0 ];then
                echo -e "\033[47;31m $1 file is Error \033[0m"
                exit 1
            fi
            if [[ $1 =~ "tar.gz" ]];then
                Dir_name=`basename $1 .tar.gz`
            else
                Dir_name=`basename $1 .tgz`
            fi
            cd $Dir_name
        #zip后缀
        elif [[ $1 =~ "zip" || $1 =~ "ZIP" ]]; then
            unzip $1
            if [ $? -ne 0 ];then
                echo -e "\033[47;31m $1 file is Error \033[0m"
                exit 1
            fi
            if [[ $1 =~ "ZIP" ]];then
                Dir_name=`basename $1 ZIP`
            else
                Dir_name=`basename $1 zip`
            fi
            cd $Dir_name
        fi
    else
        echo -e "\033[47;31m $1 file is not Found \033[0m"
        exit 2
    fi
}
#工具函数 - 用于configure是否成功
function check_Configure(){
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m $(basename `pwd`) configure fail!!!! \033[0m"
		exit 3
	else
		echo -e "\033[42;37m $(basename `pwd`)  configure successful  \033[0m"
	fi
}
#工具函数 - 用于检测make install 操作
function check_Make(){
	echo "$(basename `pwd`) start make......."
	make > /dev/null
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m $(basename `pwd`) make fail!!!! \033[0m"
		exit 4
	else
		echo -e "\033[42;37m $(basename `pwd`)  make successful  \033[0m"
		echo "$(basename `pwd`) start make install......."
		make install >/dev/null
		if [ $? -ne 0 ];then
			echo -e "\033[47;31m $(basename `pwd`) make install fail!!!! \033[0m"
			exit 5
		else
			echo -e "\033[42;37m $(basename `pwd`)  make install successful  \033[0m"
		fi
	fi
}
######~~~~~~~~~~~~~~~~~~~系统初始化函数部分~~~~~~~~~~~~~~~~~~~
#系统环境初始化函数 - 系统环境初始化通用
function init_System(){
    #安装基础库
    yum install lsof bc nc wget gcc* gcc-c++* autoconf automake gd gd-devel openssh openssh-clients openssl openssl-devel zlib \
    zlib-devel sysstat make unzip zip pciutils perl-XML-Dumper lrzsz ntp ntpdate vim python-setuptools libevent-devel mysql-devel \
	ncurses ncurses-devel pcre pcre-devel popt-devel -y >/dev/null

	#清空防火墙,并关闭
	/sbin/iptables -F
    /sbin/iptables -X
    /sbin/iptables -Z
    /sbin/iptables -F INPUT
    /sbin/iptables -P INPUT ACCEPT
    /sbin/iptables -P OUTPUT ACCEPT
    /sbin/iptables -P FORWARD DROP
	/etc/init.d/iptables save
    /etc/init.d/iptables stop

	#永久关闭SELINUX
	/usr/sbin/setenforce 0
	sed -i 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

	#关闭IPV6
	echo "alias net-pf-10 off" >> /etc/modprobe.d/dist.conf
    echo "alias ipv6 off" >> /etc/modprobe.d/dist.conf
    /sbin/chkconfig --level 35 ip6tables off


	#扩大ulimit限制
	ulimit -n 102400
	echo '* soft nofile 102400' >> /etc/security/limits.conf
    echo '* hard nofile 102400' >> /etc/security/limits.conf
    echo '* soft nproc 102400' >> /etc/security/limits.conf
    echo '* hard nproc 102400' >> /etc/security/limits.conf
}

######~~~~~~~~~~~~~~~~~~~环境安装函数部分~~~~~~~~~~~~~~~~~~~
#安装 libevent库-memcache的依赖库
function install_Libevent(){
	cd $Download_dir
    wget "http://monkey.org/~provos/libevent-1.4.14b-stable.tar.gz"
    Libevent_name=libevent-1.4.14b-stable.tar.gz
    check_File $Libevent_name
	echo "$(basename `pwd`) start configure......."
    ./configure --prefix=$Install_dir/libevent/ >/dev/null
	check_Configure


	check_Make
	echo "$Install_dir/libevent/lib" >> /etc/ld.so.conf.d/soft.conf
	ldconfig
	echo -e "\033[42;37m libevent install successful  \033[0m"

}
#安装libmcrypt库 - php的依赖库
function install_Libmcrypt(){
	cd $Download_dir
	wget http://nchc.dl.sourceforge.net/project/mcrypt/Libmcrypt/2.5.8/libmcrypt-2.5.8.tar.gz
	Libmcrypt_name=libmcrypt-2.5.8.tar.gz
    check_File $Libmcrypt_name

	echo "$(basename `pwd`) start configure......."
	./configure --prefix=$Install_dir/libmcrypt >/dev/null
	check_Configure

	check_Make

	echo "$Install_dir/libmcrypt/lib" >> /etc/ld.so.conf.d/soft.conf
	ldconfig
	echo -e "\033[42;37m libmcrypt install successful  \033[0m"
}
#安装pip - aws的机器必须安装,也可用作平时安装pip用
function install_PIP(){
	#依赖关系检查
    yum install python-setuptools -y
	#开始安装
	cd $Download_dir
    wget "https://pypi.python.org/packages/source/p/pip/pip-7.1.2.tar.gz"
    PIP_name=pip-7.1.2.tar.gz
    check_File $PIP_name
    Dir_name=`basename $PIP_name .tar.gz`
    /usr/bin/python setup.py build >/dev/null \
    &&/usr/bin/python setup.py install >/dev/null \
    &&echo -e "\033[42;37m pip install successful  \033[0m"
    if [ $? -ne 0 ];then
        echo -e "\033[47;31m pip install fails \033[0m"
        exit 10
    fi
}
#安装memcached服务 - 通用
function install_Memcached(){
	#检测依赖关系
	(ldconfig -v | grep "libevent") || install_Libevent
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m  libevent library not found \033[0m"
		exit 2
	fi

	#开始下载安装
	cd $Download_dir
    wget "http://www.memcached.org/files/memcached-1.4.25.tar.gz"
	Memcached_name=memcached-1.4.25.tar.gz
	check_File $Memcached_name

	echo "$(basename `pwd`) start configure......."
	./configure --prefix=$Install_dir/memcached --with-libevent=$Install_dir/libevent/ >/dev/null
	check_Configure

	check_Make
	#生成命令文件
	ln -sf $Install_dir/memcached /usr/local/memcached
	cat > /etc/init.d/memcached <<eof
#!/bin/bash
Memcached="/data/local/memcached/bin/memcached"
#Proc_num=\`ps -ef | grep \$Memcached | grep -v grep | awk '{print $2}' | wc -l\`
function start(){
    Proc_num=\`ps -ef | grep \$Memcached | grep -v grep | awk '{print $2}' | wc -l\`
    if [ \$Proc_num -eq 0 ];then
        \$Memcached -d -m 1024 -u root -l 127.0.0.1 -p 11211 -c 10000  -P /tmp/memcached1.pid
        echo -n "Starting memcached:"
        echo -e "\033[40;32m              [OK] \033[0m"
    else
        echo -n "Starting memcached:"
        echo -e "\033[40;31m              [FAIL] \033[0m"
    fi
}
function stop(){
    kill -9 \`ps -ef | grep \$Memcached | grep -v grep | awk '{print \$2}'\` 2>/dev/null
    sleep 3
    Proc_num=\`ps -ef | grep \$Memcached | grep -v grep | awk '{print \$2}' | wc -l\`
    if [ \$Proc_num -eq 0 ];then
        echo -n "stop memcached:"
        echo -e "\033[40;32m                  [OK] \033[0m"
    else
        echo -n "stop memcached:"
        echo -e "\033[40;31m                  [FAIL] \033[0m"
        echo -e "\033[40;31m kill memcached PID fail \033[0m"
    fi
}
if [ ! -e \$Memcached ];then
    echo -e "\033[47;31m \$Memcached file is not found \033[0m"
    exit 2
fi
case "\$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    *)
        echo "Usage: \$0 {start|stop|restart}"
        exit 1
esac
exit \$?
eof
	chmod 755 /etc/init.d/memcached

}
#安装redis - 通用
function install_Redis(){
	#开始下载安装
	cd $Download_dir
    wget "http://download.redis.io/releases/redis-3.0.4.tar.gz"
    File_name=redis-3.0.4.tar.gz
    check_File $File_name
    Dir_name=`basename $File_name .tar.gz`
	echo "$(basename `pwd`) start make......."
    make > /dev/null
    if [ $? -ne 0 ];then
        echo -e "\033[47;31m make redis fails \033[0m"
        exit 4
    fi
    mkdir -p $Install_dir/redis/{bin,conf,data}
    cp redis.conf $Install_dir/redis/conf/ && cp src{redis-benchmark,mkreleasehdr.sh,redis-cli,redis-server,redis-sentinel,redis-check-aof,redis-check-dump} $Install_dir/redis/bin/
    if [ $? -ne 0 ];then
        echo -e "\033[47;31m redis file or dir is not exist! \033[0m"
        exit 2
    else
        echo -e "\033[42;37m redis install successful  \033[0m"
	fi
}
#安装mysql
function install_Mysql(){
	#依赖关系检查
	yum install cmake -y
	useradd mysql -M -s /sbin/nologin

	#开始下载安装
	cd $Download_dir
	wget http://cdn.mysql.com//Downloads/MySQL-5.5/mysql-5.5.46.tar.gz
	Mysql_name=mysql-5.5.46.tar.gz
    check_File $Mysql_name
	mkdir -p $Install_dir/mysql/data
	mkdir -p $Install_dir/mysql/innodb
	mkdir -p $Install_dir/mysql/log/{showlog,binlog,error}
	chown mysql:mysql -R $Install_dir/mysql

	echo "$(basename `pwd`) start Cmake......."
	cmake -DCMAKE_INSTALL_PREFIX=$Install_dir/mysql \
	-DMYSQL_UNIX_ADDR=$Install_dir/mysql/tmp/mysql.sock \
	-DDEFAULT_CHARSET=utf8 \
	-DDEFAULT_COLLATION=utf8_general_ci \
	-DWITH_EXTRA_CHARSETS:STRING=utf8,gbk \
	-DWITH_MYISAM_STORAGE_ENGINE=1 \
	-DWITH_INNOBASE_STORAGE_ENGINE=1 \
	-DWITH_MEMORY_STORAGE_ENGINE=1 \
	-DWITH_READLINE=1 \
	-DENABLED_LOCAL_INFILE=1 \
	-DMYSQL_DATADIR=$Install_dir/mysql/data \
	-DMYSQL_USER=mysql \
	-DMYSQL_TCP_PORT=3306 >/dev/null

	if [ $? -ne 0 ];then
		echo -e "\033[47;31m mysql Cmake fail \033[0m"
		exit 11
	fi

	check_Make

	chmod 755 scripts/mysql_install_db
	scripts/mysql_install_db --user=mysql --basedir=$Install_dir/mysql --datadir=$Install_dir/mysql/data
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m mysql install_db fail \033[0m"
		exit 11
	fi
	cat support-files/my-large.cnf > /etc/my.cnf
	cp support-files/mysql.server /etc/init.d/mysqld
	chmod 755 /etc/init.d/mysqld
	echo "$Install_dir/mysql/lib" >> /etc/ld.so.conf.d/soft.conf
	ldconfig -v > /dev/null

	ln -sf $Install_dir/mysql /usr/local/mysql
	echo -e "\033[42;37m Mysql install successful  \033[0m"
}
#php安装函数
function install_PHP(){
	#依赖关系检查
	useradd www -M -s /sbin/nologin
	yum install gd gd-devel gd-progs libxml2 libxml2-devel bzip2 bzip2-devel curl curl-devel readline readline-devel \
	mhash mhash-devel libedit libedit-devel sqlite sqlite-devel freetype freetype-devel libc-client-devel \
	openldap openldap-devel net-snmp-devel libjpeg-turbo libjpeg-turbo-devel openjpeg openjpeg-devel cracklib-devel -y

	(ldconfig -v | grep "libmcrypt") || install_Libmcrypt
	if [ $? -ne 0 ];then
		echo -e "\033[47;31m  libmcrypt library not found \033[0m"
		exit 2
	fi

	#开始下载安装
	cd $Download_dir
	wget   http://us1.php.net/distributions/php-5.6.14.tar.gz
	PHP_name=php-5.6.14.tar.gz
    check_File $PHP_name

	echo "$(basename `pwd`) start configure......."
	./configure --prefix=$Install_dir/php \
	--with-config-file-path=$Install_dir/php/etc \
	--enable-inline-optimization --disable-debug \
	--disable-rpath --enable-shared --enable-opcache \
	--enable-fpm \
	--with-fpm-user=www \
	--with-fpm-group=www \
	--with-mysql --with-mysqli --with-pdo-mysql=mysqlnd \
	--with-gettext --enable-mbstring --with-iconv \
	--with-mcrypt=$Install_dir/libmcrypt --with-mhash \
	--with-openssl --enable-bcmath --enable-soap \
	--with-libxml-dir --enable-pcntl --enable-shmop \
	--enable-sysvmsg --enable-sysvsem  --enable-sockets \
	--with-curl  --with-bz2 --with-readline \
	--with-png-dir --with-jpeg-dir --with-freetype-dir --with-gd >/dev/null

	check_Configure

	check_Make

	cp php.ini-production $Install_dir/php/etc/php.ini
	cp sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
	chmod 755 /etc/init.d/php-fpm
	cp $Install_dir/php/etc/php-fpm.conf.default $Install_dir/php/etc/php-fpm.conf

	ln -sf $Install_dir/php /usr/local/php
}
function install_Nginx(){
	useradd www -s /sbin/nologin >/dev/null 2>/dev/null

	cd $Download_dir
	wget http://nginx.org/download/nginx-1.8.0.tar.gz
	Nginx_name=nginx-1.8.0.tar.gz
	echo $Nginx_name
	check_File $Nginx_name
	echo "$(basename `pwd`) start configure......."
	./configure --prefix=$Install_dir/nginx \
	--user=www --group=www \
	--with-http_ssl_module \
	--with-http_flv_module \
	--with-http_gzip_static_module \
	--with-http_stub_status_module \
	--with-http_realip_module >/dev/null

	check_Configure

	check_Make

	ln -sf $Install_dir/nginx /usr/local/nginx

    #设置配置文件
    cat >$Install_dir/nginx/conf/nginx.conf <<eof
user  www;
worker_processes  auto;
events {
    worker_connections  65535;
    multi_accept on;
    use epoll;
}
http {
    include       mime.types;
    default_type  application/octet-stream;
    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent \$request_time "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    #关闭nginx版本提示
    server_tokens off;

    sendfile        on;
    tcp_nopush on;
    tcp_nodelay on;
    #tcp_nopush     on;
    #keepalive_timeout  0;
    keepalive_timeout  65;

    #开启压缩
    gzip  on;
    gzip_disable "msie6";
    gzip_min_length 1000;
    gzip_comp_level 4;
    gzip_proxied any;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    client_header_buffer_size 4k;

    #文件缓存,适用于不是频繁更新,实时性要求很是非常高的站点
    #实时性要求高和cdn源站请直接注释掉下面的cache,否则会造成一定的几率出现文件加载不完整或者是旧文件
    #open_file_cache max=65535 inactive=120s;
    #open_file_cache_valid 80s;
    #open_file_cache_min_uses 1;

	#优化fastcgi连接超时时间,减少50x错误
	fastcgi_connect_timeout 300;
	fastcgi_send_timeout 300;
	fastcgi_read_timeout 300;

    #设置虚拟主机配置文件目录
    include vhost/*.conf;
}
eof

    mkdir -p $Install_dir/nginx/conf/vhost
    cd $Install_dir/nginx/conf/vhost
    cat >default.conf<<eof

#默认用IP和没绑定的主机名访问直接断开连接
server {
    listen       80;
    #server_name  xxxxxx.com
    server_name  _;
    return 444;
}
eof

}
function print_Memu(){
	echo -e "\033[44;37m ########################################################################## \033[0m"
	echo -e "\033[44;37m # 1. System  Init                                                        # \033[0m"
	echo -e "\033[44;37m # 2. Install Nginx    1.8.0                                              # \033[0m"
	echo -e "\033[44;37m # 3. Install Mysql    5.5.46                                             # \033[0m"
	echo -e "\033[44;37m # 4. Install PHP      5.6.14                                             # \033[0m"
	echo -e "\033[44;37m # 5. Install Redis    3.0.4                                              # \033[0m"
	echo -e "\033[44;37m # 6. Install Memcache 1.4.5                                              # \033[0m"
	echo -e "\033[44;37m # 7. Install PIP      7.1.2                                              # \033[0m"
	echo -e "\033[44;37m # 8. Install LNMP                                                        # \033[0m"
	echo -e "\033[44;37m # 9. EXIT                                                                # \033[0m"
	echo -e "\033[44;37m ########################################################################## \033[0m"
	echo -e "\033[44;37m #                          Author: zeping                                # \033[0m"
	echo -e "\033[44;37m ########################################################################## \033[0m"
}
function install_Menu(){
	case $1 in
		1)
			init_System
			;;
		2)
			install_Nginx
			;;
		3)
			install_Mysql
			;;
		4)
			install_PHP
			;;
		5)
			install_Redis
			;;
		6)
			install_Memcached
			;;
		7)
			install_PIP
			;;
		8)
			install_Nginx
			install_Mysql
			install_PHP
			;;
		9)
			echo "GOOD BEY!!!"
			exit 0
			;;
		*)
            clear
			echo -e "\033[47;31m Options is not found \033[0m"
			;;
	esac
}
#函数入口
function Main(){
    Download_dir=/data/soft
	if [ ! -d $Download_dir ];then
		mkdir -p $Download_dir
	fi
	Install_dir=/data/local
	if [ ! -d $Install_dir ];then
		mkdir -p $Install_dir
	fi

	clear

	if [ -$# -lt 1 ];then
		while true;do
			#clear
			print_Memu
			echo
			echo
			echo -n "Please chose the number: "
			read NUM
			install_Menu $NUM
		done
	elif [ -$# -eq 1 ];then
		install_Menu $1
	fi

}
Main $*
