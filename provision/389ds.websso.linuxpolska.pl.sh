#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

[ -z "$EPEL_VERSION" ] && exit 1
[ -z "$EPEL_URL" ] && exit 1
[ -z "$EPEL_TARGET" ] && exit 1

EPEL_TARGET_FILE=$EPEL_TARGET/$(basename $EPEL_URL)

[ -f /vagrant/provision/bootstrap-node-rhel.sh ] && source /vagrant/provision/bootstrap-node-rhel.sh

: Hostname cannot point to loopback!
sed -i 's/^127\..*389ds.*//' /etc/hosts

# Install EPEL repo
[ ! -f $EPEL_TARGET_FILE ] && curl $EPEL_URL > $EPEL_TARGET_FILE
rpm -ihv $EPEL_TARGET_FILE

: Install 389ds with administration instance and management console
sudo yum -y install 389-ds-base 389-admin 389-console 389-admin-console 389-ds

: Add ldap user and group
sudo useradd ldap

: Setup 389ds
sudo setup-ds-admin.pl --silent --file=/vagrant/provision/config/389ds-setup.inf

: Configure Password Policy and MemberOf modules
ldapmodify -x -D "cn=Directory Manager" -w ldapsecret  -f /vagrant/provision/ldif/389ds-account-policy-plugin.ldif
ldapmodify -x -D "cn=Directory Manager" -w ldapsecret  -f /vagrant/provision/ldif/389ds-password-policy-subtree.ldif
ldapadd -x -D "cn=Directory Manager" -w ldapsecret -f /vagrant/provision/ldif/389ds-MemberOf.ldif
: Populate directory with users, groups and password policies
ldapadd -x -D "uid=admin,ou=administrators,ou=topologymanagement,o=netscaperoot" -w admin  -f /vagrant/provision/ldif/389ds-ou-users-with-password-policy.ldif
ldapadd -x -D "cn=Directory Manager" -w ldapsecret -f /vagrant/provision/ldif/389ds-connection-user.ldif
: Generate TLS keys for ldap
if [ ! -f /vagrant/tmp/ldap.crt ] || [ ! -f /vagrant/tmp/ldap.key ] ; then
  [ -f /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh ] && source /vagrant/provision/bootstrap-node-rhel-ldap-certs.sh
fi
: Install ldap certificate
openssl pkcs12 -export -inkey /vagrant/tmp/ldap.key -in /vagrant/tmp/ldap.crt -out /tmp/crt.p12 -nodes -name 'Server-Cert' -password pass:changeit
cd /etc/dirsrv/slapd-ldap
pk12util -i /tmp/crt.p12 -W changeit -d .
: Create SSL TLS configuration for 389 DS Services
ldapmodify -x -D "cn=Directory Manager" -w ldapsecret  -f /vagrant/provision/ldif/389ds-secure.ldif
ldapmodify -x -D "cn=Directory Manager" -w ldapsecret  -a -f /vagrant/provision/ldif/389ds-addRSA.ldif

: Enable and restart 389 DS services
systemctl enable dirsrv.target
systemctl restart dirsrv@ldap
systemctl enable dirsrv-admin
systemctl restart dirsrv-admin
sleep 5s

: List ldap objects
ldapsearch -x -b "dc=linuxpolska,dc=pl" -D "cn=Directory Manager" -w ldapsecret "(objectclass=*)"

exit 0
