#!/bin/bash
# FPM Packaging with Freight Hosting Script for Nagios
# Date: 23rd of May, 2014
# Version 1.0
#
# Author: John McCarthy
# Email: midactsmystery@gmail.com
# <http://www.midactstech.blogspot.com> <https://www.github.com/Midacts>
#
# To God only wise, be glory through Jesus Christ forever. Amen.
# Romans 16:27, I Corinthians 15:1-4
#---------------------------------------------------------------
######## VARIABLES ########
nagios_version=4.0.6
plugin_version=2.0.1
nrpe_version=2.15
function nagios-core(){
	# Install the prerequisite packages for Nagios
		echo
		echo -e '\e[01;34m+++ Installing the prerequisite software...\e[0m'
		apt-get install -y apache2 libapache2-mod-php5 build-essential libgd2-xpm-dev libssl-dev
		echo -e '\e[01;37;42mThe prerequisite software has been successfully installed!\e[0m'

	# Downloaded the latest Nagios Core files
		echo
		echo -e '\e[01;34m+++ Downloading the latest Nagios Core files...\e[0m'
		cd
		wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-$nagios_version.tar.gz

	# Untar the Nagios Core files
		tar xzf nagios-$nagios_version.tar.gz
		cd nagios-$nagios_version
		echo -e '\e[01;37;42mThe latest Nagios Core files have been successfully downloaded!\e[0m'

	# Configure the installation
		echo
		echo -e '\e[01;34m+++ Configuring the Nagios Core installation files...\e[0m'
		./configure --prefix=/usr/local/nagios --with-nagios-user=nagios --with-nagios-group=nagios --with-command-user=nagios --with-command-group=nagcmd
		make all

	# Add the required Nagios users and groups
		groupadd -g 9000 nagios
		groupadd -g 9001 nagcmd
		useradd -u 9000 -g nagios -G nagcmd -d /usr/local/nagios -c 'Nagios Admin' nagios
		adduser www-data nagcmd

	# Create the directories to house the installation files
		mkdir -p /tmp/installdir/nagios-core
		mkdir -p /tmp/installdir/nagios-core/etc/apache2/conf.d/

	# Makes the installation files
		make install DESTDIR=/tmp/installdir/nagios-core
		make install-init DESTDIR=/tmp/installdir/nagios-core
		make install-config DESTDIR=/tmp/installdir/nagios-core
		make install-commandmode DESTDIR=/tmp/installdir/nagios-core
		make install-webconf DESTDIR=/tmp/installdir/nagios-core

	# Create the --after-installation script for Nagios
		cat << 'EON' > /root/nagios.sh
#!/bin/bash
#Create a user to access the Nagios Web UI
        echo
        echo -e 'Choose your Nagios Web UI Username'
        read webUser

# Use this command to add subsequent users later on (eliminate the '-c' switch, which creates the file)
# htpasswd /usr/local/nagios/etc/htpasswd.users username
# **NOTE** users will only see hots/services for which they are contacts <http://nagios.sourceforge.net/docs/nagioscore/3/en/cg$
        htpasswd -c /usr/local/nagios/etc/htpasswd.users $webUser

#Changes the Ownership of the htpasswd.users file
        chown nagios:nagcmd /usr/local/nagios/etc/htpasswd.users

#Enabling nagios to start at boot time
        update-rc.d nagios defaults

# Start the NRPE Daemon
        /etc/init.d/nrpe start

# Make NRPE Start at Boot Time
        update-rc.d nrpe defaults

#Make Your Self-signed Certificates
        echo
        echo 'Choose your Certificates Name'
        read CERT
        mkdir -p /etc/apache2/ssl
        cd /etc/apache2/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:4096 -keyout $CERT.key -out $CERT.crt
        a2enmod ssl

#Configure /etc/apache2/conf.d/nagios.conf
        sed -i 's/#  SSLRequireSSL/   SSLRequireSSL/g' /etc/apache2/conf.d/nagios.conf

#Configure /etc/apache2/sites-available/nagios
        echo
        echo -e 'Choose your Server Admin Email Address'
        read EMAIL
cat << EOA > /etc/apache2/sites-available/nagios
<VirtualHost *:443>
    ServerAdmin $EMAIL
    ServerName $CERT.crt
    DocumentRoot /var/www/$CERT

    <Directory />
        Options FollowSymLinks
        AllowOverride None
    </Directory>

    <Directory /var/www/$CERT>
        Options -Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
    </Directory>

     SSLEngine On
     SSLCertificateFile /etc/apache2/ssl/$CERT.crt
     SSLCertificateKeyFile /etc/apache2/ssl/$CERT.key
</VirtualHost>
EOA

# Enable the nagios site
        a2ensite nagios

#Make DirectoryRoot Directory
        mkdir -p /var/www/$CERT

#Restart Your Apache2 Service
        service apache2 restart

# Creates the nagios.lock file
        touch /usr/local/nagios/var/nagios.lock

# Set Nagios folder Permissions
        chown nagios:nagios -R /usr/local/nagios

#Restart the Nagios service
        service nagios restart

#Restart the Nagios service one more time
        service nagios restart
EON
		echo -e '\e[01;37;42mThe Nagios Core installation files have been configured!\e[0m'

	# Use FPM to make the .deb Nagios Core package
		echo
		echo -e '\e[01;34m+++ Creating the Nagios Core package...\e[0m'
		echo
		fpm -s dir -t deb -n nagios-core -v $nagios_version -d "nagios-plugins (>=2.0.1)" -d "nrpe (>=2.15)" -d "apache2 (>= 2.2.22-13+deb7u1)" -d "libapache2-mod-php5 (>= 5.4.4-14+deb7u9)" -d "libgd2-xpm-dev" -d "libssl-dev (>= 1.0.1e-2+deb7u7)" -d "heirloom-mailx" --after-install /root/nagios.sh -C /tmp/installdir/nagios-core usr etc

	# Move the Nagios Core package to the root directory
		mv nagios-core_"$nagios_version"_amd64.deb /root
		echo
		echo -e '\e[01;37;42mThe Nagios Core package has been successfully created!\e[0m'
}
function nagios-plugins(){
	# Download the latest Nagios Plugins files
		echo
		echo -e '\e[01;34m+++ Downloading the latest Nagios Plugins files...\e[0m'
		cd
		wget http://nagios-plugins.org/download/nagios-plugins-$plugin_version.tar.gz

	# Untar the Nagios Plugins files
		tar xzf nagios-plugins-$plugin_version.tar.gz
		cd nagios-plugins-$plugin_version
		echo -e '\e[01;37;42mThe latest Nagios Plugins files have been successfully downloaded!\e[0m'

	# Configure the Nagios Plugins installation
		echo
		echo -e '\e[01;34m+++ Configuring the Nagios Plugins installation files...\e[0m'
		./configure --with-nagios-user=nagios --with-nagios-group=nagios --with-openssl=/usr/bin/openssl --enable-perl-modules --enable-libtap
		make

	# Create the directories to house the installation files
		mkdir /tmp/installdir/nagios-plugins

	# Makes the installation file
		make install DESTDIR=/tmp/installdir/nagios-plugins
		echo -e '\e[01;37;42mThe Nagios Plugin installation files have been configured!\e[0m'

	# Use FPM to make the .deb Nagios Plugins package
		echo
		echo -e '\e[01;34m+++ Creating the Nagios Plugins package...\e[0m'
		echo
		fpm -s dir -t deb -n nagios-plugins -v $plugin_version -d "libssl-dev (>= 1.0.1e-2+deb7u7)" -C /tmp/installdir/nagios-plugins usr

	# Move the Nagios Plugins package to the root directory
		mv nagios-plugins_"$plugin_version"_amd64.deb /root
		echo
		echo -e '\e[01;37;42mThe Nagios Plugins package has been successfully created!\e[0m'
}
function nrpe(){
	# Download the latest nrpe files
		echo
		echo -e '\e[01;34m+++ Downloading the latest nrpe files...\e[0m'
		cd
		wget http://sourceforge.net/projects/nagios/files/nrpe-$nrpe_version.tar.gz

	# Untar the nrpe files
		tar xzf nrpe-$nrpe_version.tar.gz
		cd nrpe-$nrpe_version
		echo -e '\e[01;37;42mThe latest nrpe files have been successfully downloaded!\e[0m'

	# Configure the nrpe installation
		echo
		echo -e '\e[01;34m+++ Configuring the nrpe installation files...\e[0m'
		./configure --with-ssl=/usr/bin/openssl --with-ssl-lib=/usr/lib/x86_64-linux-gnu
		make
		make all

	# Create the directory to house the install
		mkdir -p /tmp/installdir/nrpe/etc/init.d/

	# Makes the installtion files
		make install DESTDIR=/tmp/installdir/nrpe
		make install-plugin DESTDIR=/tmp/installdir/nrpe
		make install-daemon DESTDIR=/tmp/installdir/nrpe
		make install-daemon-config DESTDIR=/tmp/installdir/nrpe

	# Copies over the nrpe init scripts and makes it executable
		cp init-script.debian /tmp/installdir/nrpe/etc/init.d/nrpe
		chmod 700 /tmp/installdir/nrpe/etc/init.d/nrpe
		echo -e '\e[01;37;42mThe nrpe installation files have been configured!\e[0m'

	# Use FPM to make the .deb nrpe package
		echo
		echo -e '\e[01;34m+++ Creating the nrpe package...\e[0m'
		echo
		fpm -s dir -t deb -n nrpe -v $nrpe_version -C /tmp/installdir/nrpe usr etc

	# Move the Nagios Plugins package to the root directory
		mv nrpe_"$nrpe_version"_amd64.deb /root
		echo
		echo -e '\e[01;37;42mThe nrpe package has been successfully created!\e[0m'
}
function freight(){
	# Finds the Nagios Core package
		core_file=$(find -name "nagios-core*")
		core=$(echo $core_file | awk '{$0=substr($0,3,length($0)); print $0}')

	# Finds the Nagios Plugins package
		plugins_file=$(find -name "nagios-plugins_*")
		plugins=$(echo $plugins_file | awk '{$0=substr($0,3,length($0)); print $0}')

	# Finds the nrpe package
		nrpe_file=$(find -name "nrpe_$nrpe_version*")
		nrpe=$(echo $nrpe_file | awk '{$0=substr($0,3,length($0)); print $0}')

	# Adding your FPM packages to your freight repo
		echo
		echo -e '\e[33mWhat repo do you want to put these files in ?\e[0m'
		echo -e '\e[31m  Please put a space beteen each repo\e[0m'
		echo -e '\e[33;01mFor example: apt/squeeze apt/wheezy apt/trusty\e[0m'
		read -ra repo
		/usr/bin/freight add $core $plugins $nrpe ${repo[0]} ${repo[1]} ${repo[2]} ${repo[3]} ${repo[4]}
		echo
		echo -e '\e[30;01mPlease type in your GPG Key passowrd for as many repos you are adding\e[0m'
		echo
		/usr/bin/freight cache
}
function doAll(){
	# Calls Function 'nagios-core'
		echo -e "\e[33m=== Package Nagios Core ? (y/n)\e[0m"
		read yesno
		if [ "$yesno" = "y" ]; then
			nagios-core
		fi

	# Calls Function 'nagios-plugins'
		echo
		echo -e "\e[33m=== Package Nagios Plugins ? (y/n)\e[0m"
		read yesno
		if [ "$yesno" = "y" ]; then
			nagios-plugins
		fi

	# Calls Function 'nrpe'
		echo
		echo -e "\e[33m=== Package nrpe ? (y/n)\e[0m"
		read yesno
		if [ "$yesno" = "y" ]; then
			nrpe
		fi

	# Calls Function 'freight'
		echo
		echo -e "\e[33m=== Add these packages to your Freight repo ? (y/n)\e[0m"
		read yesno
		if [ "$yesno" = "y" ]; then
			freight
		fi

	# End of Script Congratulations, Farewell and Additional Information
		clear
		FARE=$(cat << EOZ


\e[01;37;42mWell done! You have created your FPM package and hosted it on your Freight repo!\e[0m

  \e[30;01mCheckout similar material at midactstech.blogspot.com and github.com/Midacts\e[0m

                            \e[01;37m########################\e[0m
                            \e[01;37m#\e[0m \e[31mI Corinthians 15:1-4\e[0m \e[01;37m#\e[0m
                            \e[01;37m########################\e[0m
EOZ
)

		#Calls the End of Script variable
		echo -e "$FARE"
		echo
		echo
		exit 0
}
# Check privileges
[ $(whoami) == "root" ] || die "You need to run this script as root."

# Welcome to the script
clear
echo
echo
echo -e '     \e[01;37;42mWelcome to Midacts Mystery'\''s FPM Packaging and Freight Hosting Script!\e[0m'
echo
echo
case "$go" in
        * )
		doAll ;;
esac

exit 0
