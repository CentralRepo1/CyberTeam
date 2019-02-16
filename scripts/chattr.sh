#!/bin/bash

# chattr +i make directories un-editable
# chattr +u makes directories un-deletable
# run as root or with sudo

chattr +i /boot/*
chattr +i /lib/*
chattr +u /bin/*
chattr +u /sbin/*
chattr +u /root/*
chattr +u /sys/*
