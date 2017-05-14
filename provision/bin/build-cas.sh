#!/bin/bash

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

: Remove previous build
rm -rf $CAS_BUILDDIR/cas-overlay
rm -rf $CAS_TARGET

: Create the build directory
mkdir $(dirname $CAS_BUILDDIR)

: Clone the maven CAS repository
git clone --single-branch $CAS_URL $CAS_BUILDDIR/cas-overlay

: Build the CAS using provided configuration of the app
cd $CAS_BUILDDIR/cas-overlay
[ -f /vagrant/provision/config/cas/pom.xml ] && cat /vagrant/provision/config/cas/pom.xml > pom.xml
if [ -f /vagrant/provision/config/cas/bootstrap.properties ]; then
  [ ! -d $CAS_BUILDDIR/cas-overlay/src/main/resources ] && mkdir -p $CAS_BUILDDIR/cas-overlay/src/main/resources
  cat /vagrant/provision/config/cas/bootstrap.properties > $CAS_BUILDDIR/cas-overlay/src/main/resources/bootstrap.properties
fi
[ -d src/main/resources/ ] && rm -rf src/main/webapp/resources
mkdir -p src/main/resources
for i in /vagrant/provision/config/cas/cas-webapp/* ; do
    cp -fra $i src/main/resources
done
./mvnw clean package
cp $CAS_BUILDDIR/cas-overlay/target/cas.war $CAS_TARGET

exit 0
