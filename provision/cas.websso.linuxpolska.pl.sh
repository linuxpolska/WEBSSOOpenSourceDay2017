#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

[ -z "$TOMCAT_VERSION" ] && exit 1
[ -z "$TOMCAT_URL" ] && exit 1
[ -z "$TOMCAT_DIR" ] && exit 1
[ -z "$TOMCAT_TARGET" ] && exit 1
[ -z "$CAS_VERSION" ] && exit 1
[ -z "$CAS_URL" ] && exit 1
[ -z "$CAS_BUILDDIR" ] && exit 1
[ -z "$CAS_TARGET" ] && exit 1
[ -z "$CAS_SERVICE_MGMNT_URL" ] && exit 1
[ -z "$CAS_SERVICE_MGMNT_TARGET" ] && exit 1

[ -f /vagrant/provision/bootstrap-node-rhel.sh ] && source /vagrant/provision/bootstrap-node-rhel.sh
[ -f /vagrant/provision/bootstrap-node-rhel-java.sh ] && source /vagrant/provision/bootstrap-node-rhel-java.sh

: Install apache
yum -y install httpd mod_ssl

: Generate certificates
if [ ! -f /vagrant/tmp/cas.crt ] || [ ! -f /vagrant/tmp/cas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-apache-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-apache-certs.sh cas.websso.linuxpolska.pl
fi

cp /vagrant/tmp/cas.key /etc/pki/tls/private
chmod 600 /etc/pki/tls/private/cas.key
cp /vagrant/tmp/cas.crt /etc/pki/tls/certs/cas.crt
chmod 600 /etc/pki/tls/certs/cas.crt
sed -i -e 's@^SSLCertificateFile.*@SSLCertificateFile /etc/pki/tls/certs/cas.crt@' \
       -e 's@^SSLCertificateKeyFile.*@SSLCertificateKeyFile /etc/pki/tls/private/cas.key@' \
/etc/httpd/conf.d/ssl.conf

: Create Apache proxy configuration for cas
cat <<\APACHECONF > /etc/httpd/conf.d/01-cas.conf
Define appname cas.websso.linuxpolska.pl
<VirtualHost *:443>
  ServerName ${appname}
  SSLCertificateFile /etc/pki/tls/certs/cas.crt
  SSLCertificateKeyFile /etc/pki/tls/private/cas.key
  SSLEngine on
  SSLProxyEngine on

  # warning, this is extremely dangerous!
  # do not disable checks in environments past DEV
  SSLProxyVerify none
  SSLProxyCheckPeerCN off
  SSLProxyCheckPeerName off
  # end of warning

  ProxyTimeout 360
  ProxyErrorOverride Off
  ProxyRequests Off
  ProxyPreserveHost On
  LimitRequestLine 9000

  ProxyPass /auth "https://127.0.0.1:8443/auth"
  ProxyPassReverse /auth "https://127.0.0.1:8443/auth"

  ProxyPass /cas-management "https://127.0.0.1:8443/cas-management"
  ProxyPassReverse /cas-management "https://127.0.0.1:8443/cas-management"

  ProxyPass /manager "https://127.0.0.1:8443/manager"
  ProxyPassReverse /manager "https://127.0.0.1:8443/manager"

  ProxyPass /host-manager "https://127.0.0.1:8443/host-manager"
  ProxyPassReverse /host-manager "https://127.0.0.1:8443/host-manager"

  RewriteEngine on
  RewriteRule ^/$ https://${appname}/auth/ [R=302]

</VirtualHost>

<VirtualHost *:80>
  ServerName ${appname}
  RewriteEngine on
  RewriteRule /(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
APACHECONF

: Enable and start Apache
systemctl enable httpd
systemctl start httpd

: Install Tomcat
tomcat_v=$(basename $TOMCAT_URL)
[ ! -f $TOMCAT_TARGET/$tomcat_v ] && curl $TOMCAT_URL > $TOMCAT_TARGET/$tomcat_v
if [ ! -d $TOMCAT_DIR/$(basename $tomcat_v .tar.gz) ] ; then
    mkdir -p $TOMCAT_DIR
    cd $TOMCAT_DIR
    tar zxvf $TOMCAT_TARGET/$tomcat_v
fi

if [ ! -d $TOMCAT_DIR/tomcat ] ; then
    ln -sf $TOMCAT_DIR/$(basename $tomcat_v .tar.gz) $TOMCAT_DIR/tomcat
fi

useradd cas
chown -R cas:cas $TOMCAT_DIR/$(basename $tomcat_v .tar.gz) $TOMCAT_DIR/tomcat

ln -sf /opt/tomcat/logs /var/log/cas


cat <<EOF >/etc/systemd/system/cas.service
# Systemd unit file for tomcat
[Unit]
Description=Apache Tomcat Web Application Container for CAS
After=syslog.target network.target

[Service]
Type=forking
PIDFile=/opt/tomcat/temp/tomcat.pid
Environment=JAVA_HOME=/usr/java/latest/
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC'
Environment='JAVA_OPTS=-Djava.awt.headless=true -Djava.security.egd=file:/dev/./urandomi -Dtomcat.util.scan.StandardJarScanFilter.jarsToScan=log4j*.jar'

ExecStart=/opt/tomcat/bin/startup.sh

User=cas
Group=cas

[Install]
WantedBy=multi-user.target
EOF

: Create tomcat certificate for CAS
[ ! -f /vagrant/tmp/cas.jks ] && openssl pkcs12 -export -inkey /vagrant/tmp/cas.key -in /vagrant/tmp/cas.crt -out /vagrant/tmp/cas.jks -nodes -name cas  -password pass:changeit
[ -f  /vagrant/tmp/cas.jks ] && cp /vagrant/tmp/cas.jks /opt/tomcat/conf/server.jks

: Copy over server configuration to make sure TLS is working and we can log in using sample users
cp /vagrant/provision/config/server.xml /opt/tomcat/conf/server.xml
cp /vagrant/provision/config/tomcat-users.xml /opt/tomcat/conf/tomcat-users.xml

: Build CAS and prepare CAS configuration
 [ ! -f /vagrant/provision/bin/build-cas ] && /vagrant/provision/bin/build-cas.sh

 : Build CAS Service management application
 [ ! -f /vagrant/provision/bin/build-cas ] && /vagrant/provision/bin/build-cas-mgmnt.sh

: Copy CAS configuration
[ ! -d /etc/cas/config ] && mkdir -p /etc/cas/config
[ ! -d /etc/cas/services ] && mkdir -p /etc/cas/services
[ -f /vagrant/provision/config/cas/cas.properties ] && cp /vagrant/provision/config/cas/cas.properties /etc/cas/config/cas.properties
[ -f /vagrant/provision/config/cas/users.properties ] && cp /vagrant/provision/config/cas/users.properties /etc/cas/config/users.properties
[ -f /vagrant/provision/config/cas/management.properties ] && cp /vagrant/provision/config/cas/management.properties /etc/cas/config/management.properties
[ -f /vagrant/provision/config/cas/log4j2.xml ] && cp /vagrant/provision/config/cas/log4j2.xml /etc/cas/
[ -f /vagrant/provision/config/cas/log4j2-mgmnt.xml ] && cp /vagrant/provision/config/cas/log4j2-mgmnt.xml /etc/cas/

chown -R root:cas /etc/cas

: Install CAS management applicaiton CAS configuration
if [ -f /vagrant/provision/config/cas/CASServiceManagementApplication-1.json ] ; then
  cp /vagrant/provision/config/cas/CASServiceManagementApplication-1.json /etc/cas/services/
  chown -R cas:cas /etc/cas/services/CASServiceManagementApplication-1.json
  chmod 770 /etc/cas/services
fi
: Install CAS administration pages CAS service configuration
if [ -f /vagrant/provision/config/cas/CASAdministratorPages-2.json ] ; then
  cp /vagrant/provision/config/cas/CASAdministratorPages-2.json /etc/cas/services/
  chown -R cas:cas /etc/cas/services/CASAdministratorPages-2.json
  chmod 770 /etc/cas/services
fi

: Make sure Tomcat will use our logging configuration
[ -f /vagrant/provision/config/cas/setenv.sh ] && cp /vagrant/provision/config/cas/setenv.sh /opt/tomcat/bin
[ -f /opt/tomcat/bin/setenv.sh ] && chmod +x /opt/tomcat/bin/setenv.sh

: Install CAS application on Servlet Container
[ -f $CAS_TARGET ] && cp $CAS_TARGET /opt/tomcat/webapps/

: Install CAS Service Management application on Servlet Container
[ -f $CAS_SERVICE_MGMNT_TARGET ] && cp $CAS_SERVICE_MGMNT_TARGET /opt/tomcat/webapps/

: Make sure all certificates will be trusted
if [ ! -f /vagrant/tmp/ldap.crt ] || [ ! -f /vagrant/tmp/ldap.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh
fi
keytool -import -alias ldap -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/ldap.crt -storepass changeit -noprompt

if [ ! -f /vagrant/tmp/apachecas.crt ] || [ ! -f /vagrant/tmp/apachecas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-apache-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-apache-certs.sh apachecas.websso.linuxpolska.pl
fi
keytool -import -alias apachecas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/apachecas.crt -storepass changeit -noprompt

if [ ! -f /vagrant/tmp/appcas.crt ] || [ ! -f /vagrant/tmp/appcas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-apache-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-apache-certs.sh appcas.websso.linuxpolska.pl
fi
keytool -import -alias appcas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/appcas.crt -storepass changeit -noprompt

if [ ! -f /vagrant/tmp/keycloak.crt ] || [ ! -f /vagrant/tmp/keycloak.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-keycloak-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-keycloak-certs.sh
fi
keytool -import -alias keycloak -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/keycloak.crt -storepass changeit -noprompt

keytool -import -alias cas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/cas.crt -storepass changeit -noprompt

 : Enable and start Tomcat with CAS
systemctl daemon-reload
systemctl enable cas
systemctl start cas
