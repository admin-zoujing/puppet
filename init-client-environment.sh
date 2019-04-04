#! /bin/bash
#client-environment安装脚本

#下载地址https://yum.puppetlabs.com/或者http://downloads.puppetlabs.com/puppet/
#1、时间时区同步，修改主机名
sourceinstall=/usr/local/src/puppet/install
ntpdate ntp1.aliyun.com
hwclock -w

hostname nginx-wh-192.168.8.51.puppet.com
echo 'HOSTNAME=nginx-wh-192.168.8.51.puppet.com' >> /etc/sysconfig/network
echo 'nginx-wh-192.168.8.51.production.puppet.com' >> /etc/hostname
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
systemctl stop firewalld && systemctl disable firewalld

#2、网络安装puppet
#rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid
yum -y install epel-release.noarch 
cd $sourceinstall
yum -y install ruby-rgen-0.6.5-2.el7.noarch.rpm 
yum -y install facter-2.4.1-1.el7.x86_64.rpm
yum -y install puppet-3.6.2-1.el7.noarch.rpm 

#rpm软件包安装puppet及puppet-server
#cd /usr/local/src/packages
#rpm -ivh /usr/local/src/packages/*.rpm --force --nodeps

#3、设置hosts
cat >> /etc/hosts <<EOF
192.168.8.50 server-wh-192.168.8.50.puppet.com
192.168.8.51 nginx-wh-192.168.8.51.puppet.com
EOF

#4、增加监听与指定服务端域名,环境
cat >> /etc/puppet/puppet.conf  <<EOF
    listen = true  
    report = true
    server = server-wh-192.168.8.50.puppet.com
    runinterval = 60
#   environment = production
    pluginsync = true
EOF

# echo 'allow server-wh-192.168.8.50.puppet.com' >> /etc/puppet/auth.conf 
sed -i '/# illustrates the default policy./a\allow server-wh-192.168.8.50.puppet.com' /etc/puppet/auth.conf
sed -i '/# illustrates the default policy./a\auth any' /etc/puppet/auth.conf
sed -i '/# illustrates the default policy./a\method save' /etc/puppet/auth.conf
sed -i '/# illustrates the default policy./a\path /run' /etc/puppet/auth.conf

#5、启动puppet客户端与服务端认证
#sed -i '/ssldir =.*/a\    server=server.puppet.com' /etc/puppet/puppet.conf
puppet agent --server=server-wh-192.168.8.50.puppet.com --no-daemonize --verbose --test
systemctl restart puppet.service 
systemctl enable puppet.service 


#测试
puppet agent --server=server-wh-192.168.8.50.puppet.com --environment production --test --noop


