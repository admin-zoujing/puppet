#! /bin/bash
#centos7.4上server-environment安装脚本

#下载地址https://yum.puppetlabs.com/或者http://downloads.puppetlabs.com/puppet/  
#1、时间时区同步，修改主机名
sourceinstall=/usr/local/src/puppet/install
ntpdate ntp1.aliyun.com
hwclock -w

hostname server-wh-192.168.8.50.puppet.com
echo 'HOSTNAME=server-wh-192.168.8.50.puppet.com' >> /etc/sysconfig/network
echo 'server-wh-192.168.8.50.puppet.com' >> /etc/hostname
sed -i 's|SELINUX=.*|SELINUX=disabled|' /etc/sysconfig/selinux 
sed -i 's|SELINUXTYPE=.*|#SELINUXTYPE=targeted|' /etc/sysconfig/selinux 
systemctl stop firewalld && systemctl disable firewalld


#2、网络安装puppet-server
#rpm -Uvh https://yum.puppetlabs.com/puppet5/puppet5-release-el-7.noarch.rpm
rm -rf /var/run/yum.pid 
rm -rf /var/run/yum.pid
yum -y install epel-release.noarch 
cd $sourceinstall
yum -y install ruby-rgen-0.6.5-2.el7.noarch.rpm 
yum -y install facter-2.4.1-1.el7.x86_64.rpm
yum -y install puppet-3.6.2-1.el7.noarch.rpm 
yum -y install puppet-server-3.6.2-1.el7.noarch.rpm 

#rpm软件包安装puppet及puppet-server
#cd /usr/local/src/packages
#rpm -ivh /usr/local/src/packages/*.rpm --force --nodeps

#3、设置hosts
cat > /etc/hosts <<EOF
192.168.8.50 server-wh-192.168.8.50.puppet.com
192.168.8.51 nginx-wh-192.168.8.51.puppet.com
EOF

#4、启动puppet服务器
# puppet master --no-daemonize --verbose 
systemctl start puppetmaster.service 
systemctl enable puppetmaster.service 

#5、手动在puppet服务器端使用puppet cert命令管理客户端的证书请求
#puppet cert --list
  #"nginx-wh-192.168.8.51.production.puppet.com" (A2:9F:B4:29:BE:BD:FB:F0:96:7C:E1:18:FD:33:16:9F)
#puppet cert --sign nginx-wh-192.168.8.51.production.puppet.com
#5、自动签发证书
#允许所有域的主机自动颁发证书
cat >> /etc/puppet/autosign.conf <<EOF
*.puppet.com
EOF
#向该文件授予/etc/puppet/files目录的权限

cat >> /etc/puppet/fileserver.conf <<EOF
[mysql]
    path /etc/puppet/modules/mysql/files
    allow *.puppet.com
EOF

#6、配置文件(files里面的文件不能有文件夹)
mkdir -p /etc/puppet/modules/mysql/{manifests,templates,files}

cat > /etc/puppet/modules/mysql/manifests/init.pp <<EOF
class mysql{
    include mysql::add_user
    include mysql::packages
    include mysql::install
}
EOF

cat > /etc/puppet/modules/mysql/manifests/add_user.pp <<EOF
class mysql::add_user {
    group {"mysql":
        ensure => "present",
        gid => 501,
        name => "mysql";
        }
    user {"mysql":
        ensure => "present",
        uid =>501,
        gid =>501,
        home => "/home/mysql",
        managehome=> "true";
        }
}
EOF

cat > /etc/puppet/modules/mysql/manifests/packages.pp <<EOF
class mysql::packages {
    file { "/usr/local/src/mysql5.7" :
        ensure  => directory,
        owner   => "root",
        group   => "root",
        path    => "/usr/local/src/mysql5.7",
        }


    file { "/usr/local/src/mysql5.7/init-mysql.sh":
        ensure => present,
        source => [
           "puppet:///modules/mysql/init-mysql.sh",
          ]  
        }
    
    file { "/usr/local/src/mysql5.7/boost_1_59_0.tar.gz":
        ensure => present,
        source => [
           "puppet:///modules/mysql/boost_1_59_0.tar.gz",
          ] 
        }


    file { "/usr/local/src/mysql5.7/cmake-3.9.3.tar.gz":
        ensure => present,
        source => [
           "puppet:///modules/mysql/cmake-3.9.3.tar.gz",
          ] 
        }

    file { "/usr/local/src/mysql5.7/mysql-5.7.24.tar.gz":
        ensure => present,
        source => [
           "puppet:///modules/mysql/mysql-5.7.24.tar.gz",
          ] 
        }


    file { "/usr/local/src/mysql5.7/mysqldump.sh":
        ensure => present,
        source => [
           "puppet:///modules/mysql/mysqldump.sh",
          ]  
        }

    file { "/usr/local/src/mysql5.7/xtrabackup.sh":
        ensure => present,
        source => [
           "puppet:///modules/mysql/xtrabackup.sh",
          ]
        }

    file { "/usr/local/src/mysql5.7/percona-toolkit-3.0.12-1.el7.x86_64.rpm":
        ensure => present,
        source => [
           "puppet:///modules/mysql/percona-toolkit-3.0.12-1.el7.x86_64.rpm",
          ]
        }

    file { "/usr/local/src/mysql5.7/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm":
        ensure => present,
        source => [
           "puppet:///modules/mysql/percona-xtrabackup-24-2.4.12-1.el7.x86_64.rpm",
          ]
        }

    file { "/usr/local/src/mysql5.7/mydbpassword.sql":
        ensure => present,
        source => [
           "puppet:///modules/mysql/mydbpassword.sql",
          ]
        }
}
EOF

cat > /etc/puppet/modules/mysql/manifests/install.pp <<EOF
class mysql::install {
     exec {"build_mysql":
         #cwd =>"/usr/local/src/mysql5.7",
         #path =>"/bin:/usr/bin:/sbin:/usr/sbin",
         #creates => "/usr/local/mysql",
         command =>"/bin/bash -x /usr/local/src/mysql5.7/init-mysql.sh",
         timeout => "0",
        }
}
EOF

mkdir -p /etc/puppet/manifests/nodes
cat >> /etc/puppet/manifests/nodes/nginx-wh-192.168.8.51.puppet.com.pp <<EOF
node 'nginx-wh-192.168.8.51.puppet.com' {
   include mysql
}
EOF
cat >> /etc/puppet/manifests/site.pp <<EOF
import "nodes/nginx-wh-192.168.8.51.puppet.com.pp"
Package {
      allow_virtual => false,
    }
EOF

#7、修改puppet.conf配置环境
cat >> /etc/puppet/puppet.conf <<EOF

[master]
autosign = /etc/puppet/autosign.conf
certname= server-wh-192.168.8.50.puppet.com
pluginsync=true
EOF

#8、修改auth.conf的访问权限
cat >> /etc/puppet/auth.conf <<EOF

allow *.puppet.com
EOF

#9、加载配置
systemctl restart puppetmaster.service 

#puppet master --no-daemonize --verbose 
