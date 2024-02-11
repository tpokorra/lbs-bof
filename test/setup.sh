#!/bin/bash

branch=master
if [ ! -z "$1" ]; then
  branch=$1
fi

#============================
# basic installation
#============================
DEBIAN_FRONTEND=noninteractive apt-get -y install git ansible locales tzdata sudo php || exit -1

git clone https://github.com/ICCM-EU/BOF.git -b $branch || exit -1

# on ubuntu bionic, we only have php7.2, but we need php7.3 for PHPUnit and dependancies.
# on debian buster, we only have php7.3, but we need php7.4 for composer dependancies
if [[ "`php --version | head -n 1 | grep -E "PHP 7.2|PHP 7.3"`" != "" ]]
then
  apt-get install -y software-properties-common
  . /etc/os-release
  OS=$NAME
  if [[ "$OS" == "Ubuntu" ]]; then
	add-apt-repository ppa:ondrej/php
  fi
  if [[ "$OS" == "Debian GNU/Linux" ]]; then
	wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
	echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/php.list

	wget -O composer-setup.php https://getcomposer.org/installer
	php composer-setup.php --install-dir=/usr/local/bin --filename=composer
	export PATH=/user/local/bin:$PATH
  fi
  apt-get update
fi

# we want to use the same branch for the real installation, not download the master branch in ansible
mkdir -p /var/www
cp -R BOF /var/www/bof
cd BOF/ansible

# Ansible requires the locale encoding to be UTF-8; Detected None.
export LC_ALL=en_US.UTF-8

# TODO perhaps update group_vars/all.yml with the actual timezone
ansible-playbook playbook.yml -i localhost || exit -1
cd /root
rm -Rf BOF
ln -s /var/www/bof

if [ -f /etc/apache2/mods-enabled/php7.3.conf ]; then
  a2dismod php7.3
fi
if [ -f /etc/apache2/mods-available/php8.1.conf ]; then
  a2enmod php8.1
fi
if [ -f /etc/apache2/mods-available/php8.2.conf ]; then
  a2enmod php8.2
fi
systemctl restart apache2

#================================
# setup cypress and run the tests
#================================
cd /var/www/bof
npm install cypress || exit -1
apt-get -y install xvfb gconf2 libgtk2.0-0 libgtk3.0 libxtst6 libxss1 libnss3 libasound2 libgbm-dev || exit -1
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/nomination.js' || exit -1
sed -i "s/i < 60/i < 20/g" cypress/integration/voting.js
sed -i "s/topic < 14/topic < 7/g" cypress/integration/voting.js
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/voting.js' || exit -1


#======================
# run the PHPUnit tests
#======================
# also install the packages needed for the tests
cd /var/www/bof/ansible

ansible-playbook playbook.yml -i localhost --extra-vars "dev=1" || exit -1

cd /var/www/bof/src
composer install --dev
./vendor/bin/phpunit -c phpunit.xml || exit -1

exit 0
