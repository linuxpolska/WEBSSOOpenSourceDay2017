#!/bin/bash

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

: Remove previous build
rm -rf $CAS_BUILDDIR/cas-mgmnt-overlay
rm -rf $CAS_SERVICE_MGMNT_TARGET

: Create the build directory
mkdir $(dirname $CAS_BUILDDIR)

: Clone the maven CAS repository
git clone --single-branch $CAS_SERVICE_MGMNT_URL $CAS_BUILDDIR/cas-mgmnt-overlay

: Build the CAS Service Application using provided configuration of the app
cd $CAS_BUILDDIR/cas-mgmnt-overlay
[ -f /vagrant/provision/config/cas/pom-mgmnt.xml ] && cat /vagrant/provision/config/cas/pom-mgmnt.xml > pom.xml
[ -d src/main/resources/ ] && rm -rf src/main/webapp/resources
mkdir -p src/main/resources
for i in /vagrant/provision/config/cas/cas-management-webapp/* ; do
    cp -fra $i src/main/resources
done
./mvnw clean package
cp $CAS_BUILDDIR/cas-mgmnt-overlay/target/cas-management.war $CAS_SERVICE_MGMNT_TARGET

exit 0
