#!/bin/bash
# a script to install server dependencies

# provide messaging colors for output to console
txtbld=$(tput bold)             # Bold
bldgrn=$(tput setaf 2) #  green
bldred=${txtbld}$(tput setaf 1) #  red
txtreset=$(tput sgr0)
elmslnecho(){
  echo "${bldgrn}$1${txtreset}"
}
elmslnwarn(){
  echo "${bldred}$1${txtreset}"
}
# Define seconds timestamp
timestamp(){
  date +"%s"
}
start="$(timestamp)"
# args expected from 1-liner are username, address and email
uname=$1
addr=$2
email=$3
# ensure we have the expected arguments
if [ -z "$uname" ]; then
  exit 1
fi
if [ -z "$addr" ]; then
  exit 1
fi
if [ -z "$email" ]; then
  exit 1
fi
# used for random password generation
char=(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N O P Q R S T U V X W Y Z)
max=${#char[*]}
# generate a random 30 digit password
pass=''
for i in `seq 1 30`
do
  let "rand=$RANDOM % 62"
  pass="${pass}${char[$rand]}"
done
# generate a random 31 digit password
key=''
for i in `seq 1 31`
do
  let "rand=$RANDOM % 62"
  key="${key}${char[$rand]}"
done

#Install Remi Collet Repository:
rpm -Uvh http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm

#Install server dependencies
yes | yum --enablerepo=remi,remi-php56 install -g -y bower git deltarpm httpd mongodb mongodb-server nodejs npm php php-common php-cli php-pear php-mysqlnd php-pecl-mongo php-gd php-mbstring php-mcrypt php-xml
#Update CentOS
yes | yum update -y
#Start the Firewall Daemon and enable automatic startup
systemctl start firewalld.service
systemctl enable firewalld.service
#Allow HTTP Access through Firewall
firewall-cmd --permanent --zone=public --add-service=http
systemctl restart firewalld.service
#Start Apache HTTP Daemon and enable automatic startup
systemctl start httpd.service
systemctl enable httpd.service
#Start MongoDB and enable automatic startup
systemctl start mongod
systemctl enable mongod

# Install Composer and set global launch
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer


#Install and Configure LearningLocker
mkdir -p /var/www
git clone https://github.com/LearningLocker/learninglocker.git /var/www/learninglocker
cd /var/www/learninglocker
composer install
#Create a new MongoDB database:
cat <<EOF | mongo

use learninglocker
db.createUser({user:'$uname',pwd:'$pass',roles:["readWrite"]})
exit
EOF
#Modify app/config/database.php with database credentials:
sed -i '' "s/\'\'/$uname" app/config/database.php
sed -i '' "s/\'\'/$pass" app/config/database.php

#Finalize LL MongoDB setup:
php artisan migrate

# establish apach host setting
echo 'DocumentRoot "/var/www/learninglocker/public"' >> /etc/httpd/conf/httpd.conf
echo '<Directory "/var/www/learninglocker/public">' >> /etc/httpd/conf/httpd.conf
echo '  AllowOverride All' >> /etc/httpd/conf/httpd.conf
echo '</Directory>' >> /etc/httpd/conf/httpd.conf

#Restart Apache
systemctl restart httpd.service
#Set ownership of directories to Apache
chown -R apache.apache /var/www/learninglocker
#Adjust URL in app/config/app.php
sed -i '' "s/http:\/\/localhost\//$addr/g" app/config/database.php

#Adjust Encryption Key in app/config/app.php
sed -i '' "s/yoursecretkey/$key" app/config/app.php
#Adjust email settings in app/config/mail.php
sed -i '' "s/null/$email" app/config/mail.php
sed -i '' "s/null/$email" app/config/mail.php

elmslnecho "Create your admin user at $addr/register"
