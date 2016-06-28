#!/bin/bash

# -------------------------------------------------------------------
# Copyright (c) 2010-2016 Denis Machard
# This file is part of the extensive testing project
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301 USA
# -------------------------------------------------------------------

#====================================================================
#
#         USAGE:  ./custom-raspi.sh
#
#   DESCRIPTION:  Custom installation of the product
#
#       OPTIONS:  ---
#        AUTHOR:  Denis Machard
#====================================================================


#. /etc/rc.d/init.d/functions

# first check for root user
if [ ! $UID -eq 1000 ]; then
    echo "This script must be run as root."
    exit 1
fi

# check if this script is called with silent 
# used with update mode
if [ $# -eq 0 ]; then
	SILENT="custom"
else
	SILENT=$1
fi 

# minimum space left to install the product, 1GB
MIN_SPACE_LEFT=1048576

APP_NAME="ExtensiveTesting"
APP_PATH="$(pwd)"
LOG_FILE="$APP_PATH/install.log"
PKG_PATH="$APP_PATH/PKG/"
APP_SRC_PATH="$(pwd)/$APP_NAME/"
PRODUCT_VERSION="$(cat "$APP_SRC_PATH"/VERSION)"
PRODUCT_SVC_NAME="$(echo $APP_NAME | sed 's/.*/\L&/')"
PRODUCT_SVC_CTRL="xtctl"


if [ "$SILENT" == "custom" -o "$SILENT" == "install" ]; then
	echo "======================================================"
	echo "=  - Installation of the $APP_NAME product -  ="
	echo "=                    Denis Machard                   ="
	echo "=               www.extensivetesting.org             ="
	echo "======================================================"
fi

# bin
PYBIN="/usr/bin/python"
UNZIP_BIN="/usr/bin/unzip"
YUM_BIN="/usr/bin/apt-get"
TAR_BIN="/bin/tar"
PERL_BIN="/usr/bin/perl"

# python extension
SELENIUM_ZIP="selenium-2.53.1-extensivetesting"
SELENIUM="selenium-2.53.1"
HTTPLIB2="httplib2-0.9.2"
UUIDLIB="uuid-1.30"
PYASN="pyasn1-0.1.9"
PYSMI="pysmi-0.0.6"
PLY="ply-3.8"
PYSNMP="pysnmp-4.3.0"
PYMSSQL="pymssql-2.1.1"
FREETDS="freetds-0.91"
PYCRYPTO="pycrypto-2.6.1"
ECDSA="ecdsa-0.11"
PARAMIKO="paramiko-1.17.0"
PIL="Imaging-1.1.7"
SETUPTOOLS="setuptools-18.3"
SUDS="suds-jurko-0.6"
REQUESTS="requests-2.7.0"
NTLM="python-ntlm-1.1.0"
KERBEROS="kerberos-1.2.2"
POSTGRESQL="psycopg2-2.6.1"
XLRD="xlrd-1.0.0"
XLWT="xlwt-1.1.2"
OPENXL="openpyxl-2.3.0-b2"
ETXMLFILE="et_xmlfile-1.0.0"
JDCAL="jdcal-1.0"
SETUPTOOLS_GIT="setuptools-git-1.1"
SCANDIR="scandir-1.1"
PYCNIC_TAR="pycnic-0.0.5-extensivetesting"
PYCNIC="pycnic-0.0.5"

# websocket module for apache, only for centos 5/6
# MOD_WSTUNNEL="mod_proxy_wstunnel.so"


usage(){
	echo "Usage: $0 filename"
	exit 1
}

exit()
{
    rm -rf "$APP_PATH"/default.cfg.tmp 1>> "$LOG_FILE" 2>&1
    exit 1
}

# add some protections before to start installation
if [ ! -d "$PKG_PATH" ]; then
        echo 'PKG folder is missing!'
        exit
fi
if [ ! -d "$APP_SRC_PATH" ]; then
        echo 'Source folder is missing!'
        exit
fi

# Get system name: raspbian or debian or ubuntu and release version
echo -n "* Detecting the operating system"
OS_NAME=$(cat /etc/issue | awk {'print $1}' | awk '{print tolower($0)}' )
OS_RELEASE=$(cat /etc/debian_version | awk {'print $1}' | awk '{print tolower($0)}' )
# the sed is here to extract the first character of the string
OS_RELEASE=$( echo $OS_RELEASE | sed -r 's/(.)[^.]*\.?/\L\1/g' )

if [ "$OS_NAME" != "raspbian" -a "$OS_NAME" != "debian" -a "$OS_RELEASE" -lt 70 ]; then
	echo "OS unknown: $OS_NAME$OS_RELEASE" >> "$LOG_FILE"
	exit 1
else
	echo -n " ($OS_NAME $OS_RELEASE)"
fi


echo -n "* Detecting the system architecture"
OS_ARCH=$(uname -m)

if [ "$OS_NAME" != "arm7l"]; then
	echo "OS arch not supported: $OS_ARCH" >> "$LOG_FILE"
	exit 1
else
	echo -n " ($OS_ARCH)"
fi


# search because it is mandatory during the installation
echo -n "* Detecting system commands"
[ -f "$PERL_BIN" ] || { echo "perl is missing" >> "$LOG_FILE"; exit 1 ;}
[ -f "$PYBIN" ] || { echo "python is missing" >> "$LOG_FILE"; exit 1 ;}
[ -f "$UNZIP_BIN" ] || { echo "unzip is missing" >> "$LOG_FILE"; exit 1 ;}
[ -f "$TAR_BIN" ] || { echo "tar is missing" >> "$LOG_FILE"; exit 1 ;}
[ -f "$YUM_BIN" ] || { echo "apt-get is missing" >> "$LOG_FILE"; exit 1 ;}


# logging version in log file
cat /etc/issue 1>> "$LOG_FILE" 2>&1
$PYBIN --version 1>> "$LOG_FILE" 2>&1

rm -rf "$APP_PATH"/$HTTPLIB2/ 1>> "$LOG_FILE" 2>&1
rm -rf "$APP_PATH"/default.cfg.tmp 1>> "$LOG_FILE" 2>&1
cp -rf "$APP_PATH"/default.cfg "$APP_PATH"/default.cfg.tmp 1>> "$LOG_FILE" 2>&1
$PERL_BIN -pi -e "s/^INSTALL=(.+)$/INSTALL=\"\1\"/g" "$APP_PATH"/default.cfg.tmp
source "$APP_PATH"/default.cfg.tmp

echo -n "* Detecting primary network address"
if [ "$SILENT" == "update" ]; then
    echo -n " ($EXTERNAL_IP)"
else
    PRIMARY_IP=$(ip addr show | grep -E '^\s*inet' | grep -m1 global | awk '{ print $2 }' | sed 's|/.*||')
    if [ "$PRIMARY_IP" == "" ]; then

        echo "No primary ip detected" >> "$LOG_FILE"
        exit 1
    else
        echo -n " ($PRIMARY_IP)"
    fi
fi


if echo "$INSTALL" | egrep -q "[[:space:]]" ; then
        echo 'Whitespace on install path not supported'
        exit 1
fi

if [ "$SILENT" == "custom" ]; then
	echo -n "* Download automatically all missing packages? [$DOWNLOAD_MISSING_PACKAGES]"
	read reply
	DL_MISSING_PKGS="${reply}"
	if [ -z "$reply" ]; then
		DL_MISSING_PKGS=$DOWNLOAD_MISSING_PACKAGES
	fi
	$PERL_BIN -i -pe "s/DOWNLOAD_MISSING_PACKAGES=.*/DOWNLOAD_MISSING_PACKAGES=$(echo $DL_MISSING_PKGS | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

	echo -n "* Install automatically all embedded packages? [$INSTALL_EMBEDDED_PACKAGES]"
	read reply
	INSTALL_EMBEDDED_PKGS="${reply}"
	if [ -z "$reply" ]; then
		INSTALL_EMBEDDED_PKGS=$INSTALL_EMBEDDED_PACKAGES
	fi
	$PERL_BIN -i -pe "s/INSTALL_EMBEDDED_PACKAGES=.*/INSTALL_EMBEDDED_PACKAGES=$(echo $INSTALL_EMBEDDED_PKGS | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

	echo -n "* In which directory do you want to install the $APP_NAME product? [$INSTALL]"
	read reply
	INSTALL_PATH="${reply}"
	if [ -z "$reply" ]; then
		INSTALL_PATH="$INSTALL"
	fi
	$PERL_BIN -i -pe "s/INSTALL=.*/INSTALL=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

	echo -n "* What is the directory that contains the init scripts? [$INITD]"
	read reply
	INITD_PATH="${reply}"
	if [ -z "$reply" ]; then
		INITD_PATH=$INITD
	fi
	$PERL_BIN -i -pe "s/INITD=.*/INITD=$(echo $INITD_PATH | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

	echo -n "* What is the external ip of your server? [$PRIMARY_IP]"
	read reply
	EXT_IP="${reply}"
	if [ -z "$reply" ]; then
		EXT_IP=$PRIMARY_IP
	fi
	$PERL_BIN -i -pe "s/EXTERNAL_IP=.*/EXTERNAL_IP=$EXT_IP/g" "$APP_PATH"/default.cfg

	echo -n "* What is the FQDN associated to the external ip of your server? [$PRIMARY_IP]"
	read reply
	EXT_FQDN="${reply}"
	if [ -z "$reply" ]; then
		EXT_FQDN=$PRIMARY_IP
	fi
	$PERL_BIN -i -pe "s/FQDN=.*/FQDN=$EXT_FQDN/g" "$APP_PATH"/default.cfg

	echo -n "* What is the database name? [$DATABASE_NAME]"
	read reply
	DB_NAME="${reply}"
	if [ -z "$reply" ]; then
		DB_NAME=$DATABASE_NAME
	fi
	$PERL_BIN -i -pe "s/DATABASE_NAME=.*/DATABASE_NAME=$DB_NAME/g" "$APP_PATH"/default.cfg

	echo -n "* What is the table prefix? [$DATABASE_TABLE_PREFIX]"
	read reply
	TABLE_PREFIX="${reply}"
	if [ -z "$reply" ]; then
		TABLE_PREFIX=$DATABASE_TABLE_PREFIX
	fi
	$PERL_BIN -i -pe "s/DATABASE_TABLE_PREFIX=.*/DATABASE_TABLE_PREFIX=$TABLE_PREFIX/g" "$APP_PATH"/default.cfg

	echo -n "* What is the ip of your mysql/mariadb server? [$MYSQL_IP]"
	read reply
	SQL_IP="${reply}"
	if [ -z "$reply" ]; then
		SQL_IP=$MYSQL_IP
	fi
	$PERL_BIN -i -pe "s/MYSQL_IP=.*/MYSQL_IP=$SQL_IP/g" "$APP_PATH"/default.cfg

	echo -n "* What is the login to connect to your mysql/mariadb server? [$MYSQL_USER]"
	read reply
	SQL_USER="${reply}"
	if [ -z "$reply" ]; then
		SQL_USER=$MYSQL_USER
	fi
	$PERL_BIN -i -pe "s/MYSQL_USER=.*/MYSQL_USER=$SQL_USER/g" "$APP_PATH"/default.cfg

	echo -n "* What is the password of previous user to connect to your mysql/mariadb server? [$MYSQL_PWD]"
	read reply
	SQL_PWD="${reply}"
	if [ -z "$reply" ]; then
		SQL_PWD=$MYSQL_PWD
	fi
	$PERL_BIN -i -pe "s/MYSQL_PWD=.*/MYSQL_PWD=$SQL_PWD/g" "$APP_PATH"/default.cfg

	echo -n "* What is the sock file of your mysql/mariadb server? [$MYSQL_SOCK]"
	read reply
	SQL_SOCK="${reply}"
	if [ -z "$reply" ]; then
		SQL_SOCK=$MYSQL_SOCK
	fi
	$PERL_BIN -i -pe "s/MYSQL_SOCK=.*/MYSQL_SOCK=$(echo $SQL_SOCK| sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

	echo -n "* Do you want to configure iptables automatically? [$CONFIG_IPTABLES]"
	read reply
	FW_CONFIG="${reply}"
	if [ -z "$reply" ]; then
		FW_CONFIG=$CONFIG_IPTABLES
	fi
	$PERL_BIN -i -pe "s/CONFIG_IPTABLES=.*/CONFIG_IPTABLES=$FW_CONFIG/g" "$APP_PATH"/default.cfg

	echo -n "* Do you want to configure php automatically? [$CONFIG_PHP]"
	read reply
	PHP_CONFIG="${reply}"
	if [ -z "$reply" ]; then
		PHP_CONFIG=$CONFIG_PHP
	fi
	$PERL_BIN -i -pe "s/CONFIG_PHP=.*/CONFIG_PHP=$PHP_CONFIG/g" "$APP_PATH"/default.cfg

	if [ "$PHP_CONFIG" = "Yes" ]; then
		echo -n "* Where is your php conf file? [$PHP_CONF]"
		read reply
		PHP_PATH="${reply}"
		if [ -z "$reply" ]; then
			PHP_PATH=$PHP_CONF
		fi
		$PERL_BIN -i -pe "s/PHP_CONF=.*/PHP_CONF=$(echo $PHP_PATH | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg
	fi

	echo -n "* Do you want to configure apache automatically? [$CONFIG_APACHE]"
	read reply
	WEB_CONFIG="${reply}"
	if [ -z "$reply" ]; then
		WEB_CONFIG=$CONFIG_APACHE
	fi
	$PERL_BIN -i -pe "s/CONFIG_APACHE=.*/CONFIG_APACHE=$WEB_CONFIG/g" "$APP_PATH"/default.cfg

	if [ "$WEB_CONFIG" = "Yes" ]; then
		echo -n "* What is the directory that contains the apache2 conf file? [$HTTPD_CONF]"
		read reply
		HTTPD_PATH="${reply}"
		if [ -z "$reply" ]; then
			HTTPD_PATH=$HTTPD_CONF
		fi
		$PERL_BIN -i -pe "s/HTTPD_CONF=.*/HTTPD_CONF=$(echo $HTTPD_PATH | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg

		echo -n "* What is the directory that contains the apache2 virtual host conf files? [$HTTPD_VS_CONF]"
		read reply
		HTTPD_VS_CONF_PATH="${reply}"
		if [ -z "$reply" ]; then
			HTTPD_VS_CONF_PATH=$HTTPD_VS_CONF
		fi
		$PERL_BIN -i -pe "s/HTTPD_VS_CONF=.*/HTTPD_VS_CONF=$(echo $HTTPD_VS_CONF_PATH | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$APP_PATH"/default.cfg
	fi

	
	echo -n "* What is the path of the openssl binary? [$OPENSSL]"
	read reply
	SSL_BIN="${reply}"
	if [ -z "$reply" ]; then
		SSL_BIN=$OPENSSL
	fi
	$PERL_BIN -i -pe "s/OPENSSL=.*/OPENSSL=$(echo $SSL_BIN | sed -e 's/[]\/()$*.^|[]/\\&/g' )/g" "$APP_PATH"/default.cfg
else
	DL_MISSING_PKGS=$DOWNLOAD_MISSING_PACKAGES
    INSTALL_EMBEDDED_PKGS=$INSTALL_EMBEDDED_PACKAGES
	INSTALL_PATH="$INSTALL"
	INITD_PATH=$INITD
	EXT_IP=$EXTERNAL_IP
	EXT_FQDN=$FQDN
	DB_NAME=$DATABASE_NAME
	TABLE_PREFIX=$DATABASE_TABLE_PREFIX
	SQL_IP=$MYSQL_IP
	SQL_USER=$MYSQL_USER
	SQL_PWD=$MYSQL_PWD
	SQL_SOCK=$MYSQL_SOCK
	FW_CONFIG=$CONFIG_IPTABLES
	PHP_CONFIG=$CONFIG_PHP
	PHP_PATH=$PHP_CONF
	WEB_CONFIG=$CONFIG_APACHE
	HTTPD_PATH=$HTTPD_CONF
	HTTPD_VS_CONF_PATH=$HTTPD_VS_CONF
	SSL_BIN=$OPENSSL
    if [ "$SILENT" == "install" ]; then
        EXT_IP=$PRIMARY_IP
        EXT_FQDN=$PRIMARY_IP
    fi
fi

# prepare
if [ "$SILENT" == "custom" -o  "$SILENT" == "install" ]; then
	if [ -f "$INSTALL_PATH"/current/VERSION ]; then
		echo "A $APP_NAME server already exists on this server!"
		echo "Bye bye"
		exit 1
	fi
fi


  ################## JUSQUE LA CA VA ####################


if [ "$DL_MISSING_PKGS" = "Yes" ]; then
	echo -ne "* Adding external libraries .\r" 
	$YUM_BIN -y install postfix dos2unix openssl tcpdump mlocate vim snmpd snmp-mibs-downloader libsnmp-dev unzip zip 1>> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages basics with apt-get" >> "$LOG_FILE"
        exit 1
    fi
        
    echo -ne "* Adding external libraries ..\r" 
	$YUM_BIN -y install mariadb-server mariadb-client 1>> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages mysql with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
    echo -ne "* Adding external libraries ...\r" 
	$YUM_BIN -y install apache2 openssl php5 php5-mysql php5-gd php-pear  1>> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages apache2 and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
     ################## JUSQUE LA CA VA ####################
 
 # policycoreutils-python  introuvable
	echo -ne "* Adding external libraries ....\r"
	$YUM_BIN -y install python-lxml python-mysqldb python-simplejson python-twisted-web python-setuptools python-ldap 1>> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages python and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
	echo -ne "* Adding external libraries .....\r"
	$YUM_BIN -y install gcc python-dev Cython 1>> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages gcc and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi

	echo -ne "* Adding external libraries ......\r"
	$YUM_BIN -y install oracle-java7-jdk >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages java and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi

	echo -ne "* Adding external libraries .......\r"
	$YUM_BIN -y install libpng-dev libjpeg-dev zlib1g-dev libfreetype6-dev liblcms-dev tk-dev python-tk nmap >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages freetype and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
	echo -ne "* Adding external libraries ........\r"
	$YUM_BIN -y install postgresql-9.1 postgresql libghc-hsql-postgresql-dev libghc-hsql-postgresql-dev >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download packages freetype and more with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
    echo -ne "* Adding alien ........\r"
	$YUM_BIN -y install alien >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Unable to download alien with apt-get" >> "$LOG_FILE"
        exit 1
    fi
    
	# chkconfig
	echo -ne "* Adding external libraries .........\r"
	if [ "$OS_RELEASE" == "7" ]; then
		chmod g-wx,o-wx ~/.python-eggs 1>> "$LOG_FILE" 2>&1
		systemctl enable $HTTPD_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
		systemctl enable $MARIADB_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
	else
		chkconfig $HTTPD_SERVICE_NAME on 345 1>> "$LOG_FILE" 2>&1
		chkconfig $MYSQL_SERVICE_NAME on 345 1>> "$LOG_FILE" 2>&1
	fi

fi

if [ "$INSTALL_EMBEDDED_PKGS" = "Yes" ]; then
    
	echo -ne "* Installing embedded libraries .\r"
	# install the latest version of httplib2
	$TAR_BIN xvf $PKG_PATH/$HTTPLIB2.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$HTTPLIB2/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
        cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$HTTPLIB2/ 1>> "$LOG_FILE" 2>&1
	
	echo -ne "* Installing embedded libraries ..\r"
	# install the latest version of uuid
	$TAR_BIN xvf $PKG_PATH/$UUIDLIB.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$UUIDLIB/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$UUIDLIB/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries ...\r"
	$TAR_BIN xvf $PKG_PATH/$PYCRYPTO.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$PYCRYPTO/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYCRYPTO/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries ....\r"
	# install the latest version of pyasn
	$TAR_BIN xvf $PKG_PATH/$PYASN.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$PYASN/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYASN/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries .....\r"
	# install the latest version of ply
	$TAR_BIN xvf $PKG_PATH/$PLY.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$PLY/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PLY/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries ......\r"
	# install the latest version of pysmi
	$TAR_BIN xvf $PKG_PATH/$PYSMI.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$PYSMI/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYSMI/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries .......\r"
	# install the latest version of pysnmp
	$TAR_BIN xvf $PKG_PATH/$PYSNMP.tar.gz  1>> "$LOG_FILE" 2>&1
    cd $APP_PATH/$PYSNMP/
        $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYSNMP/ 1>> "$LOG_FILE" 2>&1

	echo -ne "* Installing embedded libraries ........\r"
	# install the latest version of freetdts
	$TAR_BIN xvf $PKG_PATH/$FREETDS.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$FREETDS/
	./configure --enable-msdblib 1>> "$LOG_FILE" 2>&1
	make 1>> "$LOG_FILE" 2>&1
	make install 1>> "$LOG_FILE" 2>&1
        cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$FREETDS/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries .......\r"
	# install the latest version of setuptool-gits
	$TAR_BIN xvf $PKG_PATH/$SETUPTOOLS_GIT.tar.gz  1>> "$LOG_FILE" 2>&1
    cd $APP_PATH/$SETUPTOOLS_GIT/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$SETUPTOOLS_GIT/ 1>> "$LOG_FILE" 2>&1
    
	echo -ne "* Installing embedded libraries .........\r"
	# install the latest version of pymssql
	$TAR_BIN xvf $PKG_PATH/$PYMSSQL.tar.gz  1>> "$LOG_FILE" 2>&1
        cd $APP_PATH/$PYMSSQL/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	ln -s /usr/local/lib/libsybdb.so.5 /usr/lib/libsybdb.so.5  1>> "$LOG_FILE" 2>&1
	ldconfig 1>> "$LOG_FILE" 2>&1
        cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYMSSQL/ 1>> "$LOG_FILE" 2>&1

	echo -ne "* Installing embedded libraries ..........\r"
	# install php-mcrypt
	if [ "$OS_RELEASE" != "7" ]; then
		alien -i $PKG_PATH/libmcrypt-2.5.8-9.el6.x86_64.rpm 1>> "$LOG_FILE" 2>&1
		alien -i  $PKG_PATH/php-mcrypt-5.3.3-3.el6.x86_64.rpm 1>> "$LOG_FILE" 2>&1
	else
		alien -i  $PKG_PATH/libmcrypt-2.5.8-13.el7.x86_64.rpm 1>> "$LOG_FILE" 2>&1
		alien -i  $PKG_PATH/php-mcrypt-5.4.16-2.el7.x86_64.rpm 1>> "$LOG_FILE" 2>&1
	fi

	echo -ne "* Installing embedded libraries ............\r"
	$TAR_BIN xvf $PKG_PATH/$ECDSA.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$ECDSA/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$ECDSA/ 1>> "$LOG_FILE" 2>&1

	echo -ne "* Installing embedded libraries .............\r"
	$TAR_BIN xvf $PKG_PATH/$PARAMIKO.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$PARAMIKO/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PARAMIKO/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ..............\r"
	$TAR_BIN xvf $PKG_PATH/$PIL.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$PIL/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PIL/ 1>> "$LOG_FILE" 2>&1

    echo -ne "* Installing embedded libraries ...............\r"
    cd $APP_PATH
    $UNZIP_BIN $PKG_PATH/$SELENIUM_ZIP.zip  1>> "$LOG_FILE" 2>&1
    cd $APP_PATH/$SELENIUM/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$SELENIUM/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ................\r"
    cd $APP_PATH
    $UNZIP_BIN $PKG_PATH/$SETUPTOOLS.zip  1>> "$LOG_FILE" 2>&1
    cd $APP_PATH/$SETUPTOOLS/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$SETUPTOOLS/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries .................\r"
    cd $APP_PATH
    $UNZIP_BIN $PKG_PATH/$SUDS.zip  1>> "$LOG_FILE" 2>&1
    cd $APP_PATH/$SUDS/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$SUDS/ 1>> "$LOG_FILE" 2>&1

    echo -ne "* Installing embedded libraries ..................\r"
    $TAR_BIN xvf $PKG_PATH/$REQUESTS.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$REQUESTS/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$REQUESTS/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ...................\r"
    $TAR_BIN xvf $PKG_PATH/$NTLM.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$NTLM/
    $PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$NTLM/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ....................\r"
    $TAR_BIN xvf $PKG_PATH/$KERBEROS.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$KERBEROS/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$KERBEROS/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries .....................\r"
    $TAR_BIN xvf $PKG_PATH/$POSTGRESQL.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$POSTGRESQL/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$POSTGRESQL/ 1>> "$LOG_FILE" 2>&1

    echo -ne "* Installing embedded libraries ......................\r"
    $TAR_BIN xvf $PKG_PATH/$XLRD.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$XLRD/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$XLRD/ 1>> "$LOG_FILE" 2>&1

    echo -ne "* Installing embedded libraries .......................\r"
    $TAR_BIN xvf $PKG_PATH/$ETXMLFILE.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$ETXMLFILE/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$ETXMLFILE/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ........................\r"
    $TAR_BIN xvf $PKG_PATH/$JDCAL.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$JDCAL/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$JDCAL/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries .........................\r"
    $TAR_BIN xvf $PKG_PATH/$OPENXL.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$OPENXL/
	$PYBIN setup.py build 1>> "$LOG_FILE" 2>&1
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$OPENXL/ 1>> "$LOG_FILE" 2>&1

	echo -ne "* Installing embedded libraries ..........................\r"
	# install lib for postgresql
	if [ "$OS_RELEASE" != "7" ]; then
		alien -i  $PKG_PATH/libpqxx-4.0.1-2.el6.x86_64.rpm 1>> "$LOG_FILE" 2>&1
		alien -i  $PKG_PATH/libpqxx-devel-4.0.1-2.el6.x86_64.rpm 1>> "$LOG_FILE" 2>&1
	else
		alien -i  $PKG_PATH/libpqxx-4.0.1-1.el7.x86_64.rpm 1>> "$LOG_FILE" 2>&1
		alien -i  $PKG_PATH/libpqxx-devel-4.0.1-1.el7.x86_64.rpm 1>> "$LOG_FILE" 2>&1
	fi
    
    echo -ne "* Installing embedded libraries ..........................\r"
    $TAR_BIN xvf $PKG_PATH/$SCANDIR.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$SCANDIR/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$SCANDIR/ 1>> "$LOG_FILE" 2>&1
    
    echo -ne "* Installing embedded libraries ...........................\r"
    $TAR_BIN xvf $PKG_PATH/$PYCNIC_TAR.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$PYCNIC/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$PYCNIC/ 1>> "$LOG_FILE" 2>&1

    echo -ne "* Installing embedded libraries ............................\r"
    $TAR_BIN xvf $PKG_PATH/$XLWT.tar.gz  1>> "$LOG_FILE" 2>&1
	cd $APP_PATH/$XLWT/
	$PYBIN setup.py install 1>> "$LOG_FILE" 2>&1
	cd .. 1>> "$LOG_FILE" 2>&1
	rm -rf $APP_PATH/$XLWT/ 1>> "$LOG_FILE" 2>&1
    

fi

echo -n "* Detecting Apache"
[ -f "$HTTPD" ] || { echo "$HTTPD_SERVICE_NAME is missing" >> "$LOG_FILE"; exit 1;}

echo -n "* Detecting MySQL/MariaDB"
[ -f "$MYSQLD" ] || { echo "$MYSQL_SERVICE_NAME is missing" >> "$LOG_FILE"; exit 1;}

echo -n "* Detecting Postfix"
[ -f "$POSTFIX" ] || { echo "$POSTFIX_SERVICE_NAME is missing" >> "$LOG_FILE"; exit 1;}

echo -n "* Detecting Openssl"
[ -f "$OPENSSL" ] || { echo "openssl is missing" >> "$LOG_FILE"; exit 1;}

echo -n "* Detecting Php"
[ -f "$PHP_CONF" ] || { echo "php is missing" >> "$LOG_FILE"; exit 1;}

# copy source
echo -n "* Preparing destination"
if [ "$SILENT" == "custom" -o "$SILENT" == "install" ]; then
	rm -rf "$INSTALL_PATH"/$APP_NAME 1>> "$LOG_FILE" 2>&1
	rm -rf "$INSTALL_PATH"/$APP_NAME-$PRODUCT_VERSION 1>> "$LOG_FILE" 2>&1
fi
mkdir -p "$INSTALL_PATH" 1>> "$LOG_FILE" 2>&1


# checking space before install
echo -n "* Checking space left on $INSTALL_PATH"
FREE_SPACE="$(df -P $INSTALL_PATH | tail -1 | awk '{print $4}')"
if [[ $FREE_SPACE -lt $MIN_SPACE_LEFT ]]; then

    echo "Less than 1GB free space left, $FREE_SPACE bytes"
    exit 1
fi


echo -n "* Copying source files"
cp -rf "$APP_SRC_PATH"/ "$INSTALL_PATH"/ 1>> "$LOG_FILE" 2>&1
mv -f "$INSTALL_PATH"/$APP_NAME "$INSTALL_PATH"/$APP_NAME-$PRODUCT_VERSION 1>> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then

	echo "Unable to copy sources" >> "$LOG_FILE"
	exit 1
fi
rm -f "$INSTALL_PATH"/current 1>> "$LOG_FILE" 2>&1
ln -s "$INSTALL_PATH"/$APP_NAME-$PRODUCT_VERSION "$INSTALL_PATH"/current 1>> "$LOG_FILE" 2>&1


# Install the product as service
echo -n "* Adding startup service"
if [ "$OS_RELEASE" == "7" ]; then
	# update the path, espace the path with sed and the db name 
	cp -rf "$INSTALL_PATH"/current/Scripts/svr.$OS_NAME$OS_RELEASE $SYSTEMD/$PRODUCT_SVC_NAME.service 1>> "$LOG_FILE" 2>&1
	$PERL_BIN -p -i -e  "s/^PIDFile=.*/PIDFile=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')\/current\/Var\/Run\/$PRODUCT_SVC_NAME.pid/g;" $SYSTEMD/$PRODUCT_SVC_NAME.service

	$PERL_BIN -p -i -e  "s/^APP_PATH=.*/APP_PATH=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')/g;"  "$INSTALL_PATH"/current/Scripts/ctl.$OS_NAME$OS_RELEASE
	$PERL_BIN -p -i -e  "s/^DB_NAME=.*/DB_NAME=$DB_NAME/g;" "$INSTALL_PATH"/current/Scripts/ctl.$OS_NAME$OS_RELEASE
    rm -f /usr/sbin/"$PRODUCT_SVC_CTRL" 1>> "$LOG_FILE" 2>&1
	ln -s "$INSTALL_PATH"/current/Scripts/ctl.$OS_NAME$OS_RELEASE /usr/sbin/"$PRODUCT_SVC_CTRL" 1>> "$LOG_FILE" 2>&1

	systemctl enable $PRODUCT_SVC_NAME.service 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then
		echo "Unable to activate as a service" >> "$LOG_FILE"
		exit 1
	fi
else
	# update the path, espace the path with sed and the db name 
	# and make a symoblic link on init.d
	$PERL_BIN -p -i -e  "s/^APP_PATH=.*/APP_PATH=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')/g;"  "$INSTALL_PATH"/current/Scripts/svr.$OS_NAME$OS_RELEASE
	$PERL_BIN -p -i -e  "s/^DB_NAME=.*/DB_NAME=$DB_NAME/g;" "$INSTALL_PATH"/current/Scripts/svr.$OS_NAME$OS_RELEASE

    rm -f $INITD_PATH/$PRODUCT_SVC_NAME 1>> "$LOG_FILE" 2>&1
	ln -s "$INSTALL_PATH"/current/Scripts/svr.$OS_NAME$OS_RELEASE $INITD_PATH/$PRODUCT_SVC_NAME 1>> "$LOG_FILE" 2>&1
    rm -f /usr/sbin/"$PRODUCT_SVC_CTRL" 1>> "$LOG_FILE" 2>&1
	ln -s "$INSTALL_PATH"/current/Scripts/svr.$OS_NAME$OS_RELEASE /usr/sbin/"$PRODUCT_SVC_CTRL" 1>> "$LOG_FILE" 2>&1

	# activate the service
	chkconfig $PRODUCT_SVC_NAME on 345 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then
		echo "Unable to activate as a service" >> "$LOG_FILE"
		exit 1
	fi
fi


echo -n "* Adding cron scripts"

$PERL_BIN -p -i -e  "s/^INSTALL_PATH=.*/INSTALL_PATH=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')/g;"  "$INSTALL_PATH"/current/Scripts/cron.backup-tables
rm -f $CRON_DAILY/$PRODUCT_SVC_NAME-tables 1>> "$LOG_FILE" 2>&1
ln -s "$INSTALL_PATH"/current/Scripts/cron.backup-tables $CRON_DAILY/$PRODUCT_SVC_NAME-tables 1>> "$LOG_FILE" 2>&1
    
if [ "$CLEANUP_BACKUPS" = "Yes" ]; then
	$PERL_BIN -p -i -e  "s/^INSTALL_PATH=.*/INSTALL_PATH=$(echo "$INSTALL_PATH" | sed -e 's/[]\/()$*.^|[]/\\&/g')/g;"  "$INSTALL_PATH"/current/Scripts/cron.cleanup-backups
	$PERL_BIN -p -i -e  "s/^OLDER_THAN=.*/OLDER_THAN=$BACKUPS_OLDER_THAN/g;"  "$INSTALL_PATH"/current/Scripts/cron.cleanup-backups
    
    rm -f $CRON_WEEKLY/$PRODUCT_SVC_NAME-backups 1>> "$LOG_FILE" 2>&1
    ln -s "$INSTALL_PATH"/current/Scripts/cron.cleanup-backups $CRON_WEEKLY/$PRODUCT_SVC_NAME-backups 1>> "$LOG_FILE" 2>&1
fi

    
# Updating the config file
echo -n "* Updating configuration files"
$PERL_BIN -i -pe "s/^ip=.*/ip=$SQL_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^user=.*/user=$SQL_USER/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^pwd=.*/pwd=$SQL_PWD/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^sock=.*/sock=$(echo $SQL_SOCK | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^fqdn=.*/fqdn=$EXT_FQDN/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^db=.*/db=$DB_NAME/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^table-prefix=.*/table-prefix=$TABLE_PREFIX/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-ext=.*/ip-ext=$EXT_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-wsu=.*/ip-wsu=$LOCALHOST_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-esi=.*/ip-esi=$LOCALHOST_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-tsi=.*/ip-tsi=$LOCALHOST_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-psi=.*/ip-psi=$LOCALHOST_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^ip-asi=.*/ip-asi=$LOCALHOST_IP/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^mode-demo=.*/mode-demo=$MODE_DEMO/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^current-adapters=.*/current-adapters=$CURRENT_ADAPTERS/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^current-libraries=.*/current-libraries=$CURRENT_LIBRARIES/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^generic-adapters=.*/generic-adapters=$GENERIC_ADAPTERS/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^generic-libraries=.*/generic-libraries=$GENERIC_LIBRARIES/g" "$INSTALL_PATH"/current/settings.ini
$PERL_BIN -i -pe "s/^tar=.*/tar=$(echo $TAR_BIN | sed -e 's/[]\/()$*.^|[]/\\&/g')/g" "$INSTALL_PATH"/current/settings.ini
dos2unix "$INSTALL_PATH"/current/settings.ini 1>> "$LOG_FILE" 2>&1

$PERL_BIN -i -pe "s/LWF_DB_HOST.*/LWF_DB_HOST='$SQL_IP';/g" "$INSTALL_PATH"/current/Web/include/config.php
$PERL_BIN -i -pe "s/LWF_DB_USER.*/LWF_DB_USER='$SQL_USER';/g" "$INSTALL_PATH"/current/Web/include/config.php
$PERL_BIN -i -pe "s/LWF_DB_PWD.*/LWF_DB_PWD='$SQL_PWD';/g" "$INSTALL_PATH"/current/Web/include/config.php
$PERL_BIN -i -pe "s/__LWF_DB_NAME.*/__LWF_DB_NAME='$DB_NAME';/g" "$INSTALL_PATH"/current/Web/include/config.php
$PERL_BIN -i -pe "s/__LWF_DB_PREFIX.*/__LWF_DB_PREFIX='$TABLE_PREFIX';/g" "$INSTALL_PATH"/current/Web/include/config.php
dos2unix "$INSTALL_PATH"/current/Web/include/config.php 1>> "$LOG_FILE" 2>&1

# workaround, disable PrivateTmp feature for apache on centos7 only
# authorize to upload file from apache
if [ "$OS_RELEASE" == "7" ]; then
    cp -rf $SYSTEMD/$HTTPD_SERVICE_NAME.service $SYSTEMD/$HTTPD_SERVICE_NAME.service.backup 1>> "$LOG_FILE" 2>&1
    $PERL_BIN -i -pe "s/PrivateTmp=true/PrivateTmp=false/g" $SYSTEMD/$HTTPD_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
    systemctl daemon-reload 1>> "$LOG_FILE" 2>&1 
fi
 


echo -n "* Creating $PRODUCT_SVC_NAME user"
useradd $PRODUCT_SVC_NAME 1>> "$LOG_FILE" 2>&1


# set folders rights
echo -n "* Updating folders rights"
chown $HTTP_USER:$HTTP_USER "$INSTALL_PATH"/current/Var/Tests/


if [ "$FW_CONFIG" = "Yes" ]; then
	if [ "$OS_RELEASE" == "7" ]; then
		systemctl enable $IPTABLE_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
	else
		chkconfig $IPTABLE_SERVICE_NAME on 345 1>> "$LOG_FILE" 2>&1
	fi

	echo -n "* Updating iptables"
	cp -rf $IPTABLE_CONF/iptables $IPTABLE_CONF/iptables.backup 1>> "$LOG_FILE" 2>&1
	chmod +x "$APP_SRC_PATH"/Scripts/iptables.rules
	"$APP_SRC_PATH"/Scripts/iptables.rules 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then
		echo "Unable to configure iptables" >> "$LOG_FILE"
		exit 1
	fi

fi

if [ "$PHP_CONFIG" = "Yes" ]; then
	echo -n "* Updating php configuration"
	cp -rf $PHP_PATH $PHP_PATH.backup 1>> "$LOG_FILE" 2>&1
	$PERL_BIN -i -pe "s/post_max_size.*/post_max_size = $PHP_MAX_SIZE/g" $PHP_PATH
	$PERL_BIN -i -pe "s/upload_max_filesize.*/upload_max_filesize = $PHP_MAX_SIZE/g" $PHP_PATH

fi

if [ "$WEB_CONFIG" = "Yes" ]; then

	echo -n "* Updating $HTTPD_SERVICE_NAME configuration"
	cp -rf $HTTPD_PATH/apache2.conf $HTTPD_PATH/apache2.conf.backup 1>> "$LOG_FILE" 2>&1
	$PERL_BIN -i -pe "s/Listen 80.*/Listen $EXTERNAL_WEB_PORT\n/g" $HTTPD_PATH/apache2.conf 1>> "$LOG_FILE" 2>&1
	$PERL_BIN -i -pe "s/ServerSignature.*/ServerSignature Off/g" $HTTPD_PATH/apache2.conf 1>> "$LOG_FILE" 2>&1

	cp -rf $HTTPD_VS_CONF_PATH/ssl.conf $HTTPD_VS_CONF_PATH/ssl.conf.backup 1>> "$LOG_FILE" 2>&1
	$PERL_BIN -i -pe "s/Listen 443.*/Listen $EXTERNAL_WEB_PORT_SSL\n/g" $HTTPD_VS_CONF_PATH/ssl.conf 1>> "$LOG_FILE" 2>&1


	if [ "$OS_RELEASE" != "7" ]; then
		echo -n "* Adding wstunnel module"
		cp -rf "$PKG_PATH"/mod_proxy_wstunnel.so /etc/apache2/modules/

	fi

	echo -n "* Adding virtual host"
	cp -rf "$APP_SRC_PATH"/Scripts/apache2.conf "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_IP>/$EXT_IP/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_IP_LOCAL>/$LOCALHOST_IP/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_WEB_PORT>/$INTERNAL_WEB_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_RP_PORT_SSL>/$EXTERNAL_WEB_PORT_SSL/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_RP_PORT>/$EXTERNAL_WEB_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_RPC_PORT>/$INTERNAL_RPC_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_REST_PORT>/$INTERNAL_REST_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_DATA_CLIENT_PORT>/$INTERNAL_DATA_CLIENT_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_DATA_AGENT_PORT>/$INTERNAL_DATA_AGENT_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_DATA_PROBE_PORT>/$INTERNAL_DATA_PROBE_PORT/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_FQDN>/$EXT_FQDN/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_USERNAME>/$PRODUCT_SVC_NAME/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	$PERL_BIN -i -pe "s/<KEY_INSTALL>/$(echo $INSTALL_PATH/current/ | sed -e 's/[]\/()$*.^|[]/\\&/g' )/g" "$INSTALL_PATH"/current/Var/Run/apache2.conf
	dos2unix "$INSTALL_PATH"/current/Var/Run/apache2.conf 1>> "$LOG_FILE" 2>&1

	rm -f $HTTPD_VS_CONF_PATH/$PRODUCT_SVC_NAME.conf 1>> $LOG_FILE 2>&1
	ln -s "$INSTALL_PATH"/current/Var/Run/apache2.conf $HTTPD_VS_CONF_PATH/$PRODUCT_SVC_NAME.conf

fi

#######################################
#
# Restart all services
#
#######################################
if [ "$WEB_CONFIG" = "Yes" -o "$PHP_CONFIG" = "Yes" ] ; then
	echo -n "* Restarting $HTTPD_SERVICE_NAME"
	if [ "$OS_RELEASE" == "7" ]; then
		systemctl restart $HTTPD_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then

			echo "Unable to restart $HTTPD_SERVICE_NAME" >> "$LOG_FILE"
			exit 1
		fi
	else
		service $HTTPD_SERVICE_NAME restart 1>> "$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then

			echo "Unable to restart $HTTPD_SERVICE_NAME" >> "$LOG_FILE"
			exit 1
		fi
	fi

fi

if [ "$FW_CONFIG" = "Yes" ]; then
	echo -n "* Restarting firewall"
	if [ "$OS_RELEASE" == "7" ]; then
		systemctl restart $IPTABLE_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then

			echo "Unable to restart $IPTABLE_SERVICE_NAME" >> "$LOG_FILE"
			exit 1
		fi
	else
		service $IPTABLE_SERVICE_NAME restart 1>> "$LOG_FILE" 2>&1
		if [ $? -ne 0 ]; then

			echo "Unable to restart $IPTABLE_SERVICE_NAME" >> "$LOG_FILE"
			exit 1
		fi
	fi

else
	if [ "$OS_RELEASE" == "7" ]; then
		systemctl stop firewalld.service 1>> "$LOG_FILE" 2>&1
		systemctl disable firewalld.service 1>> "$LOG_FILE" 2>&1
		systemctl stop $IPTABLE_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
		systemctl disable $IPTABLE_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
	else
		service $IPTABLE_SERVICE_NAME stop 1>> "$LOG_FILE" 2>&1
		chkconfig $IPTABLE_SERVICE_NAME off 1>> "$LOG_FILE" 2>&1
	fi
fi

echo -n "* Restarting MySQL/MariaDB"
if [ "$OS_RELEASE" == "7" ]; then
	systemctl restart $MARIADB_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then

		echo "Unable to restart $MARIADB_SERVICE_NAME" >> "$LOG_FILE"
		exit 1
	fi
else
	service $MYSQL_SERVICE_NAME restart 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then
 
		echo "Unable to restart $MYSQL_SERVICE_NAME" >> "$LOG_FILE"
		exit 1
	fi
fi


echo -n "* Restarting postfix"
if [ "$OS_RELEASE" == "7" ]; then
	systemctl restart $POSTFIX_SERVICE_NAME.service 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then

		echo "Unable to restart $POSTFIX_SERVICE_NAME" >> "$LOG_FILE"
		exit 1
	fi
else
	service $POSTFIX_SERVICE_NAME restart 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then

		echo "Unable to restart $POSTFIX_SERVICE_NAME" >> "$LOG_FILE"
		exit 1
	fi
fi


echo -n "* Adding the $APP_NAME database"
cd "$INSTALL_PATH"/current/Scripts/
python add-bdd.py 1>> "$LOG_FILE" 2>&1
if [ $? -ne 0 ]; then

	echo "Unable to create the database" >> "$LOG_FILE"
	exit 1
fi


echo -n "* Starting $APP_NAME $PRODUCT_VERSION"
if [ "$OS_RELEASE" == "7" ]; then
	systemctl start $PRODUCT_SVC_NAME.service 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then

		echo "Unable to start the server" >> "$LOG_FILE"
		exit 1
	fi
else
	service $PRODUCT_SVC_NAME start 1>> "$LOG_FILE" 2>&1
	if [ $? -ne 0 ]; then

		echo "Unable to start the server" >> "$LOG_FILE"
		exit 1
	fi
fi


rm -rf "$APP_PATH"/default.cfg.tmp 1>> "$LOG_FILE" 2>&1

if [ "$SILENT" == "custom" -o  "$SILENT" == "install" ]; then
        echo "========================================================================="
        echo "- Installation terminated!"
        echo "- Continue and go to the web interface (https://$PRIMARY_IP/web/index.php)"
        echo "========================================================================="
fi

exit 0
