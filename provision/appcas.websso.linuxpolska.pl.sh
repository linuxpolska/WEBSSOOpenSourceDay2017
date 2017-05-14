#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

[ -z "$EPEL_VERSION" ] && exit 1
[ -z "$EPEL_URL" ] && exit 1
[ -z "$EPEL_TARGET" ] && exit 1
[ -z "$LIFERAY_MAJOR_VERSION" ] && exit 1
[ -z "$LIFERAY_MINOR_VERSION" ] && exit 1
[ -z "$LIFERAY_URL" ] && exit 1
[ -z "$LIFERAY_DIR" ] && exit 1
[ -Z "$LIFERAY_TARGET" ] && exit 1
[ -z "$APP_NAMES" ] && exit 1
[ -z "$WORDPRESS_CAS_URL" ] && exit 1

EPEL_TARGET_FILE=$EPEL_TARGET/$(basename $EPEL_URL)

[ -f /vagrant/provision/bootstrap-node-rhel.sh ] && source /vagrant/provision/bootstrap-node-rhel.sh

: Install java
[ -f /vagrant/provision/bootstrap-node-rhel-java.sh ] && source /vagrant/provision/bootstrap-node-rhel-java.sh

# Install EPEL repo
[ ! -f $EPEL_TARGET_FILE ] && curl $EPEL_URL > $EPEL_TARGET_FILE
rpm -ihv $EPEL_TARGET_FILE

[ -f /vagrant/provision/bootstrap-node-rhel.sh ] && source /vagrant/provision/bootstrap-node-rhel.sh

: Install apache
yum -y install httpd mod_ssl

: Install MariaDB newer version to make sure it will work with Liferay
: Create repository for newer version on MYSQL
cat <<REPO>/etc/yum.repos.d/MariaDB10.repo
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/10.1/centos7-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
REPO
: Clean the repository cache
yum clean all
: Install newer version of MariaDB
yum -y install MariaDB-server MariaDB-client

systemctl enable mariadb
systemctl start mariadb

: Setup MariaDB
mysql -u root <<MYSQLSETUP
UPDATE mysql.user SET Password=PASSWORD('admin') WHERE User='root';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.db WHERE Db='test';
CREATE USER 'app_user'@'localhost' IDENTIFIED BY 'admin123';
FLUSH PRIVILEGES;
MYSQLSETUP

for app in $APP_NAMES
do
  mysql -uroot -padmin -e "CREATE DATABASE $app CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
  mysql -uroot -padmin -e "GRANT ALL ON $app.* TO 'app_user'@'localhost';"
  mysql -uroot -padmin -e "FLUSH PRIVILEGES;"
  mysql -uroot -padmin $app < /vagrant/provision/config/$app-cas.sql
done

: Generate certificates
if [ ! -f /vagrant/tmp/appcas.crt ] || [ ! -f /vagrant/tmp/appcas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-apache-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-apache-certs.sh appcas.websso.linuxpolska.pl
fi
cp /vagrant/tmp/appcas.key /etc/pki/tls/private
chmod 600 /etc/pki/tls/private/appcas.key
cp /vagrant/tmp/appcas.crt /etc/pki/tls/certs/appcas.crt
chmod 600 /etc/pki/tls/certs/appcas.crt
sed -i -e 's@^SSLCertificateFile.*@SSLCertificateFile /etc/pki/tls/certs/appcas.crt@' \
       -e 's@^SSLCertificateKeyFile.*@SSLCertificateKeyFile /etc/pki/tls/private/appcas.key@' \
/etc/httpd/conf.d/ssl.conf

: Create Application index site
cat <<\EOF > /etc/httpd/conf.d/01-webapp-site.conf
Define appname appcas.websso.linuxpolska.pl
<VirtualHost *:443>
  ServerName ${appname}
  SSLCertificateFile /etc/pki/tls/certs/appcas.crt
  SSLCertificateKeyFile /etc/pki/tls/private/appcas.key
  SSLEngine on
  SSLProxyEngine on
  # warning, this is extremely dangerous!
  # do not disable checks in environments past DEV
  SSLProxyVerify none
  SSLProxyCheckPeerCN off
  SSLProxyCheckPeerName off

  ProxyTimeout 360
  ProxyErrorOverride Off
  ProxyRequests Off
  ProxyPreserveHost On
  LimitRequestLine 9000

  ProxyPreserveHost On
  ProxyPass /liferay ajp://127.0.0.1:8009
  ProxyPassReverse /liferay ajp://127.0.0.1:8009

  DocumentRoot /var/www/html/main_page/

  <Directory "/var/www/html/main_page/">
    AllowOverride None
    Options -Indexes
    # Allow open access:
    Require all granted
  </Directory>

</VirtualHost>

<VirtualHost *:80>
  ServerName ${appname}
  RewriteEngine on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
EOF

: Install wordpress
yum -y install wordpress

sed -i 's/Require local/Require all granted/g' /etc/httpd/conf.d/wordpress.conf
sed -i 's/database_name_here/wordpress/g' /etc/wordpress/wp-config.php
sed -i 's/username_here/app_user/g' /etc/wordpress/wp-config.php
sed -i 's/password_here/admin123/g' /etc/wordpress/wp-config.php

: Create application index page
if [ ! -d /var/www/html/main_page ] ; then
    mkdir -p /var/www/html/main_page
fi

if [ ! -f /var/www/html/main_page/index.html ] ; then
cat <<EOF2 > /var/www/html/main_page/index.html
  <h1>Strona z indeksem aplikacji WWW</h1>
  <ul>
    <li><a href="/wordpress/wp-admin">Wordpress</a> - Strona logowania</li>
    <li><a href="/liferay">LifeRay Portal CE</a> - Strona główna portalu</li>
    </ul>
EOF2
fi

: Install unzip
yum -y install unzip

: Install CAS plugin to wordpress
cas_wordpress_plugin=$(basename $WORDPRESS_CAS_URL)
[ ! -f $TARGET/$cas_wordpress_plugin ] && curl $WORDPRESS_CAS_URL > $TARGET/$cas_wordpress_plugin
unzip $TARGET/$cas_wordpress_plugin -d /usr/share/wordpress/wp-content/plugins

: Install Liferay Portal
liferay_v=$(basename $LIFERAY_URL)
[ ! -f $LIFERAY_TARGET/$liferay_v ] && curl $LIFERAY_URL > $LIFERAY_TARGET/$liferay_v
if [ ! -d $LIFERAY_DIR/$(basename $liferay_v .zip) ] ; then
    cd /opt
    unzip $LIFERAY_TARGET/$liferay_v
fi
echo $(basename $liferay_v "-$LIFERAY_MINOR_VERSION")
if [ -d $LIFERAY_DIR ] ; then
    ln -sf $LIFERAY_DIR /opt/liferay
fi

cat <<TOMCATCONF >/etc/systemd/system/liferay.service
# Systemd unit file for tomcat running liferay
[Unit]
Description=Apache Tomacat with LifeRay Web Application
After=syslog.target network.target

[Service]
Type=forking

Environment=JAVA_HOME=/usr/java/latest/
Environment=CATALINA_PID=/opt/liferay/tomcat-8.0.32/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/liferay/tomcat-8.0.32
Environment=CATALINA_BASE=/opt/liferay/tomcat-8.0.32
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandomi -Dtomcat.util.scan.StandardJarScanFilter.jarsToScan=log4j*.jar'
PIDFile=/opt/liferay/tomcat-8.0.32/temp/tomcat.pid
ExecStart=/opt/liferay/tomcat-8.0.32/bin/startup.sh

User=liferay
Group=liferay

[Install]
WantedBy=multi-user.target
TOMCATCONF

cat <<DBLIFERAYCONF >/opt/liferay/tomcat-8.0.32/webapps/ROOT/WEB-INF/classes/portal-ext.properties
jdbc.default.driverClassName=org.mariadb.jdbc.Driver
jdbc.default.url=jdbc:mariadb://localhost/liferay?useUnicode=true&characterEncoding=UTF-8&useFastDateParsing=false
jdbc.default.username=app_user
jdbc.default.password=admin123

portal.proxy.path=/liferay
company.login.prepopulate.domain=false
company.security.strangers=false
company.security.auth.type=screenName
web.server.https.port=443
web.server.forwarded.host.enabled=true
web.server.forwarded.host.header=X-Forwarded-Host
web.server.forwarded.port.enabled=true
web.server.forwarded.port.header=X-Forwarded-Port
web.server.forwarded.protocol.enabled=true
web.server.forwarded.protocol.header=X-Forwarded-Proto

open.sso.auth.enabled=false
com.liferay.portal.servlet.filters.sso.opensso.OpenSSOFilter=false
DBLIFERAYCONF

cat <<PORTALINIT >/opt/liferay-ce-portal-7.0-ga3/portal-setup-wizard.properties
admin.email.from.address=admin@websso.linuxpolska.pl
admin.email.from.name=Administrator Portalu
company.default.name=Open Source Day 2017 SSO Workshop::CAS
default.admin.first.name=Administrator
default.admin.last.name=Portalu
liferay.home=/opt/liferay-ce-portal-7.0-ga3
setup.wizard.add.sample.data=on
setup.wizard.enabled=false

PORTALINIT

: Create tomcat certificate for liferay
[ ! -f /vagrant/tmp/appcas.jks ] && openssl pkcs12 -export -inkey /vagrant/tmp/appkeycloak.key -in /vagrant/tmp/appcas.crt -out /vagrant/tmp/appcas.jks -nodes -name liferay  -password pass:changeit
[ -f  /vagrant/tmp/appcas.jks ] && cp /vagrant/tmp/appcas.jks /opt/liferay/tomcat-8.0.32/conf/server.jks

: Make cas certifcate trusted by java vm
if [ ! -f /vagrant/tmp/cas.crt ] || [ ! -f /vagrant/tmp/cas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-apache-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-apache-certs.sh cas.websso.linuxpolska.pl
fi
[ -f /vagrant/tmp/cas.crt ] && keytool -import -alias cas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/cas.crt -storepass changeit -noprompt

: Make ldap certificate trusted by java vm
if [ ! -f /vagrant/tmp/ldap.crt ] || [ ! -f /vagrant/tmp/ldap.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh
fi
[ -f /vagrant/tmp/ldap.crt ] && keytool -import -alias ldap -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/ldap.crt -storepass changeit -noprompt

: Make app cas certifcate trusted
[ -f /vagrant/tmp/appcas.crt ] && keytool -import -alias appcas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/appcas.crt -storepass changeit -noprompt

: Copy over server configuration to make sure TLS is working
cp /vagrant/provision/config/server.xml /opt/liferay/tomcat-8.0.32/conf/server.xml

useradd liferay
chown -R liferay:liferay $LIFERAY_DIR /opt/liferay

systemctl daemon-reload
systemctl enable liferay
systemctl start liferay
systemctl enable httpd
systemctl restart httpd

exit 0
