#!/bin/bash

Pid_File=/data/local/nginx/logs/nginx.pid
Log_Path=/data/local/nginx/logs
Backup_Path=/data/logs/nginx

if [ ! -d "$Backup_Path" ];then
    mkdir -p $Backup_Path
fi

cd $Log_Path
for Log_Name in $(ls | grep -i ".log$");do
    mv $Log_Name $Backup_Path/$Log_Name.$(date +%Y%m%d%H%M) >/dev/null 2>&1
done


kill -USR1 $(cat $Pid_File) >/dev/null 2>&1

#删除7天前创建的文件
find $Backup_Path -mtime +7 -type f | xargs rm -rf
