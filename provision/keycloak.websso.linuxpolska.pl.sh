#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

[ -z "$KEYCLOAK_VERSION" ] && exit 1
[ -z "$KEYCLOAK_URL" ] && exit 1
[ -z "$KEYCLOAK_DIR" ] && exit 1
[ -z "$KEYCLOAK_TARGET" ] && exit 1

[ -f /vagrant/provision/bootstrap-node-rhel.sh ] && source /vagrant/provision/bootstrap-node-rhel.sh
[ -f /vagrant/provision/bootstrap-node-rhel-java.sh ] && source /vagrant/provision/bootstrap-node-rhel-java.sh

: Install Apache and use it as reverse proxy
yum -y install httpd mod_ssl

cat <<\EOF > /etc/httpd/conf.d/01-keycloak-site.conf
Define appname keycloak.websso.linuxpolska.pl
<VirtualHost *:443>
  ServerName ${appname}
  SSLCertificateFile /etc/pki/tls/certs/keycloak.crt
  SSLCertificateKeyFile /etc/pki/tls/private/keycloak.key
  SSLEngine on
  SSLProxyEngine on
  # warning, this is extremely dangerous!
  # do not disable checks in environments past DEV
  SSLProxyVerify none
  SSLProxyCheckPeerCN off
  SSLProxyCheckPeerName off
  # end of warning

  ProxyTimeout 120
  ProxyErrorOverride Off
  ProxyRequests Off
  ProxyPreserveHost On
  LimitRequestLine 9000

  ProxyPreserveHost On
  ProxyPass / https://127.0.0.1:8443/
  ProxyPassReverse / https://127.0.0.1:8443/

</VirtualHost>

<VirtualHost *:80>
  ServerName ${appname}
  RewriteEngine on
  RewriteRule ^/(.*) https://%{SERVER_NAME}/$1 [R,L]
</VirtualHost>
EOF

: Install KeyKloak
keycloak_v=$(basename $KEYCLOAK_URL)
[ ! -f $KEYCLOAK_TARGET/$keycloak_v ] && curl $KEYCLOAK_URL > $KEYCLOAK_TARGET/$keycloak_v
if [ ! -d $KEYCLOAK_DIR/$(basename $keycloak_v .tar.gz) ] ; then
    mkdir -p $KEYCLOAK_DIR
    cd $KEYCLOAK_DIR
    tar zxvf $KEYCLOAK_TARGET/$keycloak_v
fi

if [ ! -d $KEYCLOAK_DIR/keycloak ] ; then
    ln -sf $KEYCLOAK_DIR/$(basename $keycloak_v .tar.gz) $KEYCLOAK_DIR/keycloak
fi

useradd keycloak
chown -R keycloak:keycloak $KEYCLOAK_DIR/$(basename $keycloak_v .tar.gz)  $KEYCLOAK_DIR/keycloak

ln -sf /opt/keycloak/standalone/log /var/log/keycloak

if [ ! -d /etc/keycloak ] ; then
  mkdir -p /etc/keycloak
fi

cp /opt/keycloak/docs/contrib/scripts/systemd/launch.sh /opt/keycloak/bin/

# We will destroy user password security - just for fun couse we can
: Lowering paswword policies to let us use easy to remember passwords -- this is not production but testing enviroment
sed -i "s/wildfly/keycloak/g" /opt/keycloak/bin/launch.sh
sed -i "s/minLength=8/minLength=5/g" /opt/keycloak/bin/add-user.properties
sed -i "s/minDigit=1/minDigit=0/g" /opt/keycloak/bin/add-user.properties
sed -i "s/minSymbol=1/minSymbol=0/g" /opt/keycloak/bin/add-user.properties
sed -i "s/mustNotMatchUsername=TRUE/mustNotMatchUsername=FASLE/g" /opt/keycloak/bin/add-user.properties
sed -i "s/forbiddenValue=root,admin,administrator/forbiddenValue=root,administrator/g" /opt/keycloak/bin/add-user.properties
sed -i "s/strength=MEDIUM/strength=VERY_WEAK/g" /opt/keycloak/bin/add-user.properties

sed -i 's/inet-address value="${jboss.bind.address.management:127.0.0.1}"/any-address/g' /opt/keycloak/standalone/configuration/standalone.xml

/opt/keycloak/bin/add-user.sh -u admin -p admin
/opt/keycloak/bin/add-user-keycloak.sh -u admin -p admin

cat <<ECONF >/etc/keycloak/keycloak.conf
# The configuration you want to run
KEYCLOAK_CONFIG=standalone.xml

# The mode you want to run
KEYCLOAK_MODE=standalone

# The address to bind to
KEYCLOAK_BIND=127.0.0.1

ECONF

cat <<EOF >/etc/systemd/system/keycloak.service
# Systemd unit file for tomcat
[Unit]
Description=The KeyKloak SSO Solution
After=syslog.target network.target
Before=httpd.service

[Service]
RuntimeDirectory=keycloak
RuntimeDirectoryMode=0750
Environment=LAUNCH_JBOSS_IN_BACKGROUND=1
Environment=JBOSS_LOG_DIR=/opt/keycloak/standalone/log
Environment=JBOSS_PIDFILE=/var/run/keycloak/keycloak.pid
EnvironmentFile=-/etc/keycloak/keycloak.conf
User=keycloak
Group=keycloak
LimitNOFILE=102642
PIDFile=/var/run/keycloak/keycloak.pid
ExecStart=/opt/keycloak/bin/launch.sh \$KEYCLOAK_MODE \$KEYCLOAK_CONFIG \$KEYCLOAK_BIND
TimeoutStartSec=60
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
EOF

: Generate and copy tls certificate
[ -f /vagrant/provision/bootstrap-node-rhel-keycloak-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-keycloak-certs.sh
[ -f /vagrant/tmp/keycloak.jks ] && cp /vagrant/tmp/keycloak.jks /opt/keycloak/standalone/configuration/
[ -f /opt/keycloak/standalone/configuration/keycloak.jks ] && chown keycloak:keycloak /opt/keycloak/standalone/configuration/keycloak.jks

cp /vagrant/tmp/keycloak.key /etc/pki/tls/private
chmod 600 /etc/pki/tls/private/keycloak.key
cp /vagrant/tmp/keycloak.crt /etc/pki/tls/certs/keycloak.crt
chmod 600 /etc/pki/tls/certs/keycloak.crt

: Add tls configuration to WildFly
sed -i '/<security-realms>/a\
    <security-realm name="SslRealm">\
    <server-identities>\
    <ssl>\
    <keystore path="keycloak.jks" relative-to="jboss.server.config.dir" keystore-password="changeit"/>\
    </ssl>\
    </server-identities>\
    </security-realm>' /opt/keycloak/standalone/configuration/standalone.xml

sed -i '/<security-realm name="ManagementRealm">/a\
    <server-identities>\
    <ssl>\
    <keystore path="keycloak.jks" relative-to="jboss.server.config.dir" keystore-password="changeit"/>\
    </ssl>\
    </server-identities>' /opt/keycloak/standalone/configuration/standalone.xml

sed -i '/<socket-binding http="management-http"\/>/a\
    <socket-binding https="management-https"\/>' /opt/keycloak/standalone/configuration/standalone.xml

sed -i 's/<socket-binding http="management-http"\/>/<!--<socket-binding http="management-http"\/>-->/g' /opt/keycloak/standalone/configuration/standalone.xml

sed -i '/<http-listener name="default" socket-binding="http"\/>/a\
    <https-listener name="default-https" socket-binding="https" security-realm="SslRealm"\/>' /opt/keycloak/standalone/configuration/standalone.xml

sed  -i '/<http-listener name="default" socket-binding="http" redirect-socket="https"\/>/a\
    <https-listener name="default-ssl" socket-binding="https" security-realm="SslRealm" />' /opt/keycloak/standalone/configuration/standalone.xml

sed -i 's/${jboss.management.https.port:9993}/${jboss.management.https.port:4993}/g' /opt/keycloak/standalone/configuration/standalone.xml

: Add Keycloak logging configuration to WildFly
sed -i '/<\/periodic-rotating-file-handler>/a\
<async-handler name="FATAL_KEYCLOAK_ASYNC">\
  <level name="FATAL"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_FATAL"/>\
  </subhandlers>\
</async-handler>\
<async-handler name="TRACE_KEYCLOAK_ASYNC">\
  <level name="TRACE"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_TRACE"/>\
  </subhandlers>\
</async-handler>\
<async-handler name="WARN_KEYCLOAK_ASYNC">\
  <level name="WARN"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_WARN"/>\
  </subhandlers>\
</async-handler>\
<async-handler name="ERROR_KEYCLOAK_ASYNC">\
  <level name="ERROR"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_ERROR"/>\
  </subhandlers>\
</async-handler>\
<async-handler name="INFO_KEYCLOAK_ASYNC">\
  <level name="INFO"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_INFO"/>\
  </subhandlers>\
</async-handler>\
<async-handler name="DEBUG_KEYCLOAK_ASYNC">\
  <level name="DEBUG"/>\
  <queue-length value="1024"/>\
  <overflow-action value="block"/>\
  <subhandlers>\
    <handler name="KEYCLOAK_DEBUG"/>\
  </subhandlers>\
</async-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_TRACE">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-trace.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_DEBUG">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-debug.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_INFO">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-info.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_WARN">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-warn.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_ERROR">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-error.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<periodic-rotating-file-handler name="KEYCLOAK_FATAL">\
  <formatter>\
    <named-formatter name="PATTERN"/>\
  </formatter>\
  <file relative-to="jboss.server.log.dir" path="keycloak-fatal.log"/>\
  <suffix value=".yyyy-MM-dd"/>\
  <append value="true"/>\
</periodic-rotating-file-handler>\
<logger category="org.keycloak">\
  <level name="TRACE"/>\
  <handlers>\
    <handler name="TRACE_KEYCLOAK_ASYNC"/>\
    <handler name="DEBUG_KEYCLOAK_ASYNC"/>\
    <handler name="INFO_KEYCLOAK_ASYNC"/>\
    <handler name="WARN_KEYCLOAK_ASYNC"/>\
    <handler name="ERROR_KEYCLOAK_ASYNC"/>\
    <handler name="FATAL_KEYCLOAK_ASYNC"/>\
  </handlers>\
</logger>\
<!--<logger category="io.undertow">\
  <level name="TRACE"/>\
  <handlers>\
    <handler name="TRACE_KEYCLOAK_ASYNC"/>\
    <handler name="DEBUG_KEYCLOAK_ASYNC"/>\
    <handler name="INFO_KEYCLOAK_ASYNC"/>\
    <handler name="WARN_KEYCLOAK_ASYNC"/>\
    <handler name="ERROR_KEYCLOAK_ASYNC"/>\
    <handler name="FATAL_KEYCLOAK_ASYNC"/>\
  </handlers>\
</logger>-->' /opt/keycloak/standalone/configuration/standalone.xml

: Make sure all certificates will be trusted by java vm running keycloak
if [ ! -f /vagrant/tmp/apachekeycloak.crt ] || [ ! -f /vagrant/tmp/apachekeycloak.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-certs.sh apachekeycloak.websso.linuxpolska.pl
fi
keytool -import -alias apachekeycloak -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/apachekeycloak.crt -storepass changeit -noprompt
if [ ! -f /vagrant/tmp/appkeycloak.crt ] || [ ! -f /vagrant/tmp/appkeycloak.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-certs.sh appkeycloak.websso.linuxpolska.pl
fi
keytool -import -alias appkeycloak -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/appkeycloak.crt -storepass changeit -noprompt
if [ ! -f /vagrant/tmp/ldap.crt ] || [ ! -f /vagrant/tmp/ldap.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh
fi
keytool -import -alias ldap -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/ldap.crt -storepass changeit -noprompt

if [ ! -f /vagrant/tmp/cas.crt ] || [ ! -f /vagrant/tmp/cas.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-certs.sh cas.websso.linuxpolska.pl
fi
keytool -import -alias cas -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/cas.crt -storepass changeit -noprompt

keytool -import -alias keycloak -keystore /opt/java/jre/lib/security/cacerts -file /vagrant/tmp/keycloak.crt -storepass changeit -noprompt

systemctl daemon-reload
systemctl enable keycloak.service
systemctl start keycloak.service
systemctl enable httpd
systemctl start httpd
