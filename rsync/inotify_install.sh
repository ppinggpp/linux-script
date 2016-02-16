#!/bin/bash
#Author: zeping

function install_Inotify(){
    cd $Download_dir
    #wget http://sourceforge.net/projects/inotify-tools/files/latest/download/inotify-tools-3.13.tar.gz
    tar zxf  inotify-tools-3.13.tar.gz && cd inotify-tools-3.13
    ./configure && make && make install
    if [ $? -eq 0 -a -f '/usr/local/bin/inotifywait' ];then
        echo "inotify tools is install successful"
    else
        echo -e "\033[31m \033[05m inotify tools install fail !!!!!!!! \033[0m"
        exit 1
    fi
}

function create_Inotify_Script(){
    cat >$Script_dir/rsync_inotify.sh<<eof
#!/bin/bash
#需要同步的服务器地址
Dst_Host=192.168.1.1

#源文件目录
Src_Dir=/webserver/

#需要同步的远程服务器上的模块名
Dst_Module=WEB
#远程服务器上的模块认证用户
Module_UserName=xxxxxx
#rsync命令的绝对路径
Rsync_Pwd=`whereis rsync | awk '{print $2}'`
/usr/local/bin/inotifywait -mrq --timefmt '%d/%m/%y %H:%M' \\
--format '%T %w%f %e' \\
-e modify,delete,create,attrib \$Src_Dir \\
| while read files
do
\$Rsync_Pwd -vzrtopg --delete  --password-file=/etc/rsyncd.pass \$Src_Dir \$Module_UserName@\$Dst_Host::\$Dst_Module
echo "\$files was rsyncd!" >>  /var/log/rsync_inotify.log
done
eof

}

function main(){

    Download_dir=/data/soft
	if [ ! -d $Download_dir ];then
		mkdir -p $Download_dir
	fi

    Script_dir=/data/tools/rsync
    if [ ! -d $Script_dir ];then
		mkdir -p $Script_dir
	fi

    if [ -f "/usr/local/bin/inotifywait" -a -f "/usr/local/bin/inotifywatch" ];then
        echo "inotify tools is exist"
        exit 0
    else
        install_Inotify
        create_Inotify_Script
    fi
}

main $*
