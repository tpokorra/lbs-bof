#!/bin/bash

branch=master
if [ ! -z "$1" ]; then
  branch=$1
fi

#============================
# basic installation
#============================
DEBIAN_FRONTEND=noninteractive apt-get -y install git ansible locales tzdata sudo || exit -1
git clone https://github.com/ICCM-EU/BOF.git -b $branch || exit -1
# we want to use the same branch for the real installation, not download the master branch in ansible
mkdir -p /var/www
cp -R BOF /var/www/bof
cd BOF/ansible
# perhaps update group_vars/all.yml with the actual timezone
# python3: on Ubuntu Bionic, force python3, to make creation of mysql db work (otherwise it complains: "The MySQL-python module is required")
ansible-playbook playbook.yml -i localhost -e 'ansible_python_interpreter=/usr/bin/python3' || exit -1
cd /root
rm -Rf BOF
ln -s /var/www/bof

#================================
# setup cypress and run the tests
#================================
cd /var/www/bof
npm install cypress || exit -1
apt-get -y install xvfb gconf2 libgtk2.0-0 libgtk3.0 libxtst6 libxss1 libnss3 libasound2 || exit -1
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/nomination.js' || exit -1
sed -i "s/i < 60/i < 20/g" cypress/integration/voting.js
sed -i "s/topic < 14/topic < 7/g" cypress/integration/voting.js
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/voting.js' || exit -1


#======================
# run the PHPUnit tests
#======================
# also install the packages needed for the tests
cd /var/www/bof/ansible
ansible-playbook playbook.yml -i localhost -e 'ansible_python_interpreter=/usr/bin/python3' --extra-vars "dev=1" || exit -1
# on ubuntu bionic, we only have php7.2, but we need php7.3 for PHPUnit and dependancies.
if [[ "`php --version | head -n 1 | grep "PHP 7.2"`" != "" ]]
then
  apt-get install -y software-properties-common
  add-apt-repository ppa:ondrej/php
  apt-get update
  apt-get install -y php7.4 php7.4-dom php7.4-mbstring php7.4-xdebug php7.4-pdo-sqlite
fi

cd /var/www/bof/src
composer install --dev
./vendor/bin/phpunit -c phpunit.xml || exit -1

exit 0
