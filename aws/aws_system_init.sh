#!/bin/bash
#aws 系统初始化脚本 包含 自动格式化硬盘   自动挂载到/data目录


function format_Disk() {
    mkdir /data >/dev/null 2>&1
    UsedDisk=`df -h | grep "/$" | awk '{gsub("1","",$1)}{print $1}'`
    UnusedDisk=`fdisk -l 2>/dev/null |grep -i "^Disk /dev" | egrep -v "identifier|${UsedDisk}" | awk '{gsub(":","",$2)}{print $2}' | head -n 1`
    if ! df -h | grep -qi "${UnusedDisk}";then
        DiskSize=`fdisk -l "${UnusedDisk}" | grep -i "cylinders$" | awk '{print $5}'`
        echo -ne "#!/bin/bash\nfdisk ${UnusedDisk} << EOF > /dev/null 2>&1\n"> /tmp/mount2disk_arg.sh
        echo -ne "n\np\n1\n\n\n\n\nw\nq\nEOF\n" >> /tmp/mount2disk_arg.sh
        EchoGreen "The System Beginning Format Disk ${UnusedDisk}"
        chmod u+x /tmp/mount2disk_arg.sh && /tmp/mount2disk_arg.sh > /dev/null 2>&1
        sleep 1
        mkfs.ext4 ${UnusedDisk}1 >/dev/null 2>&1
        mount ${UnusedDisk}1 /data && echo -ne "${UnusedDisk}1 /data     ext4    defaults,acl     0 0" >> /etc/fstab
        mount -o remount,rw /data >/dev/null 2>&1
        rm -f /tmp/mount2disk_arg.sh
        EchoGreen "The System Format Disk ${UnusedDisk} Successed,it is mounted to /data"
    fi
}

function init_System(){

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

    #格式化硬盘,并挂载到 /data目录
    format_ Disk
}

init_System
