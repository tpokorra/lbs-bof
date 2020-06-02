#!/bin/bash

#============================
# basic installation
#============================
apt-get -y install git ansible locales || exit -1
git clone https://github.com/ICCM-EU/BOF.git || exit -1
cd BOF/ansible
# perhaps update group_vars/all.yml with the actual timezone
ansible-playbook playbook.yml -i localhost || exit -1
cd /root
rm -Rf BOF
ln -s /var/www/bof

#============================
# setup for tests
#============================
cd /var/www/bof
npm install cypress || exit -1
apt-get -y install xvfb gconf2 libgtk2.0-0 libxtst6 libxss1 libnss3 libasound2 || exit -1
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/nomination.js' || exit -1
LANG=en CYPRESS_baseUrl=http://localhost ./node_modules/.bin/cypress run --config video=false --spec 'cypress/integration/voting.js' || exit -1

exit 0
