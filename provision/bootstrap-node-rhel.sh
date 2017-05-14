#!/bin/sh

set -x

[ -f /vagrant/provision/variables ] && source /vagrant/provision/variables

: Tools useful for debugging and development + all editors to make every one happy - use what u like
yum -y install vim telnet nmap tcpdump git openldap-clients nano emacs-nox bash-completion bash-completion-extras chrony

: Enable syntax highlighting in vim editor
echo syntax on >> /etc/virc

: Enable syntax highlighting in nano editor
sed -i '/^# include /s/^#//' /etc/nanorc

: Disable firewall so it doesnt come in the way
systemctl stop firewalld
systemctl disable firewalld

: Enable chrony to make sure our time is synchronized
systemctl enable chronyd
systemctl start chronyd
