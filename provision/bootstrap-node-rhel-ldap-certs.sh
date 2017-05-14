: Make SSL/TLS certificates for LDAP server
if [ ! -f /vagrant/tmp/ldap.crt ] || [ ! -f /vagrant/tmp/ldap.key ] ; then
    openssl req -nodes -sha256 -new -days 3650 -x509 -subj \
    "/C=PL/CN=ldap.websso.linuxpolska.pl/subjectAltName=DNS.1=ldap.websso.linuxpolska.pl,DNS.2=389ds.websso.linuxpolska.pl" \
    -keyout /vagrant/tmp/ldap.key \
    -out /vagrant/tmp/ldap.crt
fi
