: Make SSL/TLS certificates for Kecloak servers
if [ ! -f /vagrant/tmp/keycloak.crt ] || [ ! -f /vagrant/tmp/keckloak.key ] ; then
    openssl req -nodes -sha256 -new -x509 -days 3650 -subj \
    "/C=PL/CN=keycloak.websso.linuxpolska.pl/subjectAltName=DNS.1=keycloak.websso.linuxpolska.pl" \
    -keyout /vagrant/tmp/keycloak.key \
    -out /vagrant/tmp/keycloak.crt
fi
: Install KeyCloak certificate in
if [ ! -f /vagrant/tmp/keycloak.jks ] ; then
  openssl pkcs12 -export -inkey /vagrant/tmp/keycloak.key -in /vagrant/tmp/keycloak.crt -out /vagrant/tmp/keycloak.jks -nodes -name keycloak  -password pass:changeit
fi
