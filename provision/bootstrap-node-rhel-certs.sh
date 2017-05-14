hostname=$1
certname=$(echo $hostname | cut -d. -f1)
: Make SSL/TLS certificates for Apache server
if [ ! -f /vagrant/tmp/$certname.crt ] || [ ! -f /vagrant/tmp/$certname.key ] ; then
    openssl req -nodes -sha256 -new -x509 -days 3650 -subj \
    "/C=PL/CN=$hostname" \
    -keyout /vagrant/tmp/$certname.key \
    -out /vagrant/tmp/$certname.crt
fi
