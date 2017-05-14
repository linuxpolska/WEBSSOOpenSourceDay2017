#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

[ -z "$JDK_BASE_URL_8" ] && exit 1
[ -z "$JDK_VERSION" ] && exit 1
[ -z "$JDK_PLATFORM" ] && exit 1
[ -z "$JDK_TARGET" ] && exit 1

: Install JDK
jdkfile=$JDK_TARGET/$(basename $JDK_BASE_URL_8)$JDK_PLATFORM

[ ! -f $jdkfile ] && curl -L -H "Cookie: oraclelicense=accept-securebackup-cookie" -k "${JDK_BASE_URL_8}${JDK_PLATFORM}" >$jdkfile
rpm -qa jdk* | grep -q jdk || rpm -ihv $jdkfile

[ ! -d /opt ] && mkdir -p /opt
ln -sf /usr/java/latest /opt/java

