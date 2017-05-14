#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

sed -i "s/^SELINUX=permissive/SELINUX=enforcing/" /etc/selinux/config
