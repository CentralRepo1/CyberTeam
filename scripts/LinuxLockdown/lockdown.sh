#!/bin/bash

## Part 1: Prerequisites

# Force Root execution
if [[ $UID -ne 0 ]]
then
    echo 'Please run the script as root and try again.' >&2
    exit 1
fi

# Ensure the system in Linux based
if [[ "$OSTYPE" -ne "linux-gnu" ]]
then
    echo 'This system is not a Linux-based system, this script is only compatible with Linux' >&2
    exit 2
fi

## Part 2: Enumeration and Report

# Create Report file in tmp directory
REPORT='./report.txt'
echo
if [[ -f $REPORT ]]
then
    echo "lockdown_report.txt already exists, we're going to add this report to the end of it."
    echo
    echo "----------------------------------------------------" >> $REPORT
    echo "Enumeration report for" `date` >> $REPORT
    echo "----------------------------------------------------" >> $REPORT
    echo "" >> $REPORT
else
    touch ./report.txt
    echo "----------------------------------------------------" >> $REPORT
    echo "Enumeration report for" `date` >> $REPORT
    echo "----------------------------------------------------" >> $REPORT
    echo "" >> $REPORT
fi

# Create Log file in tmp directory
LOG='./log.txt'
if [[ -f $LOG ]]
then
    echo "The log file for this script already exists, we're going to add to the end of it"
    echo
    echo "--------------------------------------------------" >> $LOG
    echo "Lockdown Log file for" `date` >> $LOG
    echo "--------------------------------------------------" >> $LOG
    echo "" >> $LOG
else
    touch ./log.txt
    echo "--------------------------------------------------" >> $LOG
    echo "Lockdown Log file for" `date` >> $LOG
    echo "--------------------------------------------------" >> $LOG
    echo "" >> $LOG
fi

# System Info
printf "\n \n" >> $REPORT
printf "		SYSTEM SUMMARY \n" >> $REPORT
printf "Hostname:			$(uname -n) \n" >> $REPORT
printf "Operating System:		$(uname -o) \n" >> $REPORT
printf "Distribution:			$(sed -n '/DISTRIB_ID/p' /etc/*-release | awk -F "=" '{print $2}') \n" >> $REPORT
printf "Version:                       $(sed -n '/VERSION_ID/p' /etc/*-release | awk -F "=" '{print $2}') \n" >> $REPORT
printf "Kernal Name: 			$(uname -s) \n" >> $REPORT
printf "Kernel Release:			$(uname -r) \n" >> $REPORT
printf "Kernel Version: 		$(uname -v) \n" >> $REPORT
printf "System Architecture:		$(uname -m) \n" >> $REPORT
printf "\n \n" >> $REPORT

# Network Information
printf "		NETWORK INTERFACE SUMMARY \n" >> $REPORT
printf "$( ip addr show | sed -n '/valid/!p' | awk -F " " '{print $2}') \n" >> $REPORT
printf "\n \n" >> $REPORT

# DNS Information
printf "		DNS SERVER SUMMARY \n" >> $REPORT
printf "$(sed -n '/nameserver/p' /etc/resolv.conf  | awk -F" " '{print $2}') \n" >> $REPORT
printf "\n \n" >> $REPORT

#Check who has sudo access
cat /etc/sudoers 2>&1 | tee /tmp/canIsudo &>/dev/null 
CANSUDO="$(cat /tmp/canIsudo | awk -F":" '{print $3}')"
if [[ $CANSUDO == " Permission denied" ]]
then
	printf "\n \t \t Cannot access /etc/sudoers file, skipping this check. \n \n"
else
USER="printf "$(cat /etc/passwd | awk -F":" '{print $1}')"" >> $REPORT
GROUP="printf "$(cat /etc/group | awk -F":" '{print $1}')"" >> $REPORT
printf "\n" >> $REPORT
printf "        	USERS WITH SUDO PRIVILEGES \n \n" >> $REPORT
fi

for i in $USER
do
USERSUDO="$(grep -e "$i"  /etc/sudoers | sed -n '/#/!p' | sed -n '/User_Alias/!p' | sed -n '/root/!p' | sed -n '/bin/!p')"
if [[ $USERSUDO != "" ]]
then
printf "$i \n" >> $REPORT
fi
done
printf "\n" >> $REPORT
printf "        	GROUPS WITH SUDO PRIVILEGES \n \n" >> $REPORT

for i in $GROUP
do
GROUPSUDO="$(grep -e "$i" /etc/sudoers | sed -n '/#/!p' | sed -n '/bin/!p' | sed -n '/User_Alias/!p' | sed -n '/root/!p')"
if [[ $GROUPSUDO != "" ]]
then
printf "$i \n" >> $REPORT
printf "Users in "$i" group:" >> $REPORT
printf "$(cat /etc/group | sed -n "/$i/p" | awk -F ":" '{$1=$2=$3="";print $0}')" >> $REPORT
printf "\n \n" >> $REPORT
fi
done
printf "\n \n" >> $REPORT

# Checking if any entries include NOPASSWD
for i in $USER
do
NOPASSWD_SUDO="$(sed -n '/NOPASSWD/p' /etc/sudoers | sed -n '/#/!p' | sed -n '/root/!p' | sed -n "/$i/p" | awk '{print $1}')"
if [ "$NOPASSWD_SUDO" != "" ]
then
printf "		WARNING \nUser $i SUDOERS configuration contains NOPASSWD \n" >> $REPORT
fi
done

for i in $GROUP
do
NOPASSWD_SUDO="$(sed -n '/NOPASSWD/p' /etc/sudoers | sed -n '/#/!p' | sed -n '/root/!p' | sed -n "/$i/p" | awk '{print $1}')"
if [ "$NOPASSWD_SUDO" != "" ]
then
printf "		WARNING \nGroup $i SUDOERS configuration contains NOPASSWD \n" >> $REPORT
fi
done

# Check existing cron jobs on the system
# printf "              ALL USERS ON MACHINE WITH ACTIVE CRON JOBS" &> $REPORT
# printf "$(for user in $(cut -f1 -d: /etc/passwd); do sudo crontab -u $user -l; done) \n" >> $REPORT


if [[ $? -eq 0 ]]
then
    echo 'Enumeration Report Successful'
    echo
    echo 'Enumeration Report Succeeded' >> $LOG
    enum="true"
else
    echo 'Error generating enumeration report.' >&2
    echo 'Continuing script'
    echo 'Enumeration Report Failed' >> $LOG
    enum="false"
fi

## Part 3: Configuration Hardening

# Apply the correct package manager
## NOTE: Remember to come back and double check these install -y commands
ALPINE="false"
function packageManager ()
{
    if [[ $(which apt) = "/usr/bin/apt" ]] > /dev/null
    then
        echo "apt package manager detected"
        echo "Updating packages ..."
        INSTALL="apt-get install -y"
        apt-get update -y > /dev/null
        elif [[ $(Which dpkg) = "/usr/bin/dpkg" ]] > /dev/null
        then
        echo "debian package manager detected"
        echo "Please install apt package manager and try again."
        exit 9
    else
        echo "Package manager could not be detected"
        echo "Which package manager are you using?"
        echo
        echo "  1) apt"
        echo "  2) dpkg"
        echo "  3) yum"
        echo "  4) rpm"
        echo "  5) apk"
        echo "  6) Let me exit the script so I can go check"
        echo "  7) My package manager isn't listed"
        echo
        read pkg
        case $pkg in
            1)
            echo "apt Selected"
            echo "Updating packages ..."
            INSTALL="apt-get install -y"
            apt-get update -y > /dev/null
            ;;
            2)
            echo "dpkg selected"
            echo "Please download the apt package manager and try again."
            exit 9
            ;;
            3)
            echo "yum Selected"
            echo "Updating packages ..."
            yum install -y epel-release
            yum update -y > /dev/null
            INSTALL="yum install -y"
            ;;
            4)
            echo "rpm selected"
            echo "Please download the yum package manager and try again"
            exit 5
            ;;
            5)
            echo "apk selected"
            echo "Updating packages..."
            echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
            apk update > /dev/null
            INSTALL="apk add"
            ALPINE="true"
            ;;
            6)
            echo "Ok, exiting script"
            exit 6
            ;;
            7)
            echo "Sorry, those are the only supported package managers at this time."
            echo "This script cannot continue any further."
            echo "This systems package manager is not compatible with this script" >> $LOG
            ;;
            *)
            echo "Invalid choice, please try again"
            packageManager
            ;;
        esac
    fi
}
packageManager
echo

# FTP Hardening
echo "Hardening FTP..."
VSFTPD_CONFIG=/etc/vsftpd.conf
if [[ -f "$VSFTPD_CONFIG" ]]
then
    rm "$VSFTPD_CONFIG"
    cp ./configs/vsftpd_config "$VSFTPD_CONFIG"
    FTP_DETECT="yes"
    echo "FTP Hardening complete"
    echo
else
    function FTP_option ()
    {
        echo "vsftpd not found, would you like to install it? (yes/no)"
        read vsftpd
        case $vsftpd in
            yes)
            echo "Installing vsftpd..."
            $INSTALL vsftpd > /dev/null
            cp ./configs/vsftpd_config "$VSFTPD_CONFIG"
            cat $VSFTPD_CONFIG > /dev/null
            if [[ $? -eq 0 ]]
            then
                touch /etc/vsftpd.allowed_users
                echo "FTP Hardening successful"
                echo "Allowed Users file created to /etc/vsftpd.allowed_users"
                echo
                echo "FTP Hardening Succeeded" >> $LOG
                FTP_DETECT="yes"
            else
                echo "Error Hardening FTP."
                echo "Continuing Script."
                echo "FTP Hardening Failed" >> $LOG
                FTP_DETECT="no"
            fi
            ;;
            no)
            echo "Skipping FTP Hardening..."
            echo
            echo "FTP Hardening was skipped by user" >> $LOG
            FTP_DETECT="no"
            ;;
            *)
            echo "Invalid option, please enter yes or no"
            FTP_option
        esac
    }
    FTP_option
fi

# SSH
SSH_CONFIG=/etc/ssh/sshd_config
function SSH_option ()
{
    if [[ -f "$SSH_CONFIG" ]]
    then
        echo 'SSH Detected'
        echo 'Hardening SSH...'
        echo 'Would you like to utilize passwords for SSH? Or only use keys?'
        echo "  1) Keys Only"
        echo "  2) Keys and Passwords"
        echo "  3) Skip SSH Hardening and continue"
        echo "  4) Quit Script"
        echo
        echo "Please enter an option 1-4:"

        read n
        case $n in
            1)
            echo "You have chosen to only utilize keys."
            echo
            cp ./configs/keys_sshd_config $SSH_CONFIG
            if [[ $? -eq 0 ]]
            then
                echo "SSH Hardening Successful"
                echo "SSH Hardening Succeeded" >> $LOG
                SSH_DETECT="yes"
            else
                echo "Error Hardening SSH Config File"
                echo "Continuing script"
                echo "SSH Hardening Failed" >> $LOG
                SSH_DETECT="no"
            fi
            ;;
            2)
            echo "You have chosen to utilize keys and passwords."
            rm /etc/ssh/sshd_config > /dev/null
            cp ./configs/passes_sshd_config /etc/ssh/sshd_config
            if [[ $? -eq 0 ]]
            then
                echo "SSH Hardening Successful"
                echo "SSH Hardening Succeeded" >> $LOG
                SSH_DETECT="yes"
            else
                echo "Error Hardening SSH Config File"
                echo "Continuing script"
                echo "SSH Hardening Failed" >> $LOG
                SSH_DETECT="no"
            fi
            ;;
            3)
            echo "You have chosen to skip SSH Hardening and continue with the script."
            echo "SSH Hardening was skipped by user" >> $LOG
            SSH_DETECT="no"
            ;;
            4)
            echo "Quitting script."
            exit 4
            ;;
            *)
            echo "Invalid input, please try again"
            SSH_option
            ;;
        esac
    else
            echo "SSH not detected, skipping..."
            echo "SSH was not detected, therefore it was not hardened" >> $LOG
    fi
}
SSH_option

## Part 4: iptables configuration

# Install uncomplicated firewall (ufw)
function ufw_option ()
{
    echo
    echo "Would you like to enable and configure firewall rules? (yes/no)"
    echo
    read firewall_opt

    case $firewall_opt in
    yes)
    if [[ $ALPINE = true ]]
    then
        echo "Installing Uncomplicated Firewall (ufw)..."
        $INSTALL ip6tables ufw@testing > /dev/null
        if [[ $? -eq 0 ]]
        then
            echo "ufw installed successfully"
            echo "ufw installation succeeded" >> $LOG
            ufw_enabled="yes"
        else
            echo "There was an error installing ufw, skipping this step..."
            echo "Error downloading ufw" >> $LOG
            ufw_enabled="no"
        fi
    else
        echo "Installing Uncomplicated Firewall (ufw)..."
        $INSTALL ufw > /dev/null
        if [[ $? -eq 0 ]]
        then
            echo "ufw installed successfully"
            echo "ufw installation succeeded" >> $LOG
            ufw_enabled="yes"
        else
            echo "There was an error downloading ufw, skipping this step..."
            echo "Error downloading ufw" >> $LOG
            ufw_enabled="no"
        fi
    fi
    ;;
    no)
        echo "Skipping firewall rules..."
        echo "Firewall rules skipped by user" >> $LOG
        ufw_enabled="no"
    ;;
    *)
        echo "That was an invalid input, please enter yes or no"
        ufw_option
    ;;
    esac
}
ufw_option

# Set default ufw rules to deny incoming traffic and allow outgoing traffic
if [ "$ufw_enabled" = "yes" ]
then
    echo "Setting firewall rules to allow outgoing traffic, and deny incoming traffic, unless stated otherwise"
    ufw default deny incoming >/dev/null
    ufw default allow outgoing > /dev/null
fi

# ufw FTP rule
FTP_RULE ()
{
    if [ "$FTP_DETECT" = "yes" ] && [ "$ufw_enabled" = "yes" ]
    then
        echo
        echo "FTP was detected earlier, would you like to allow FTP through the firewall? (yes/no)"
        echo
        read FTP_ufw_option

        case $FTP_ufw_option in
        yes)
            ufw allow 20/tcp > /dev/null
            ufw allow 21/tcp > /dev/null
            if [[ $? -eq "0" ]]
            then
                echo
                echo "FTP Successfully Allowed"
                echo "FTP Rule Allowed Successfully" >> $LOG
            else
                echo
                echo "Failed to allow FTP through firewall, you can do it manually by looking up the syntax for ufw"
                echo "FTP Rule Allow Failed, you can do it manually by looking up the syntax for ufw" >> $LOG
            fi
        ;;
        no)
            echo
            echo "Not allowing FTP through firewall..."
            echo "User decided not to let FTP through firewall" >> $LOG
        ;;
        *)
            echo "That was not a valid option, please select yes or no" 
            FTP_RULE
        ;;
        esac
    fi
}
FTP_RULE

# ufw SSH Rule
function SSH_RULE ()
{
    if [ "$SSH_DETECT" = "yes" ] && [ "$ufw_enabled" = "yes" ];
    then
        echo
        echo "SSH was detected earlier, would you like to allow SSH through the firewall? (yes/no)"
        echo
        read SSH_ufw_option

        case $SSH_ufw_option in
        yes)
            ufw allow ssh > /dev/null
            if [[ $? -eq 0 ]]
            then
                echo
                echo "SSH Allowed Successfully"
                echo
                echo "SSH Rule Allowed Successfully" >> $LOG
            else
                echo "Failed to allow SSH through the firewall, you can do it manually by looking up the syntax for ufw"
                echo
                echo "SSH Rule allow failed, you can do it manually by looking up the syntax for ufw" >> $LOG
                echo >> $LOG
            fi
        ;;
        no)
            echo "Not allowing SSH through the firewall"
            echo
            echo "User decided to not allow SSH through the firewall" >> $LOG
        ;;
        *)
            echo "That was not a valid option, please choose yes or no"
            echo
            SSH_RULE
        ;;
        esac
    fi
}
SSH_RULE

# Allow user to open additional ports if necessary
function user_port ()
{
    echo "Are there any other ports you wish to allow through the firewall? (yes/no)"
    echo
    read port_opt

    case $port_opt in
    yes)
        echo "Ok, is it a TCP port, or a UDP port? (TCP/UDP)"
        echo
        read tcp_udp
        
        case $tcp_udp in
        TCP)
            echo "Ok, which port number?"
            echo
            read port
            ufw allow $port/tcp > /dev/null
            if [[ $? -eq 0 ]]
            then
                echo "Port allowed successfully"
                echo
                echo "User succesfully allowed port $port/tcp through the firewall" >>$LOG
                user_port
            else
                echo "There was an error allowing the port through"
                echo "Would you like to try again? (yes/no)"
                echo
                read port_retry
                
                case $port_retry in
                yes)
                    user_port
                ;;
                no)
                    echo "Ok, skipping step"
                    echo
                    echo "User skipped adding extra firewall rules after initial failure" >> $LOG
                ;;
                *)
                    echo "That was an invalid input, please try again"
                    user_port
                ;;
                esac
            fi
        ;;
        UDP)
            echo "Ok, which port number?"
            echo
            read port
            ufw allow $port/udp > /dev/null
            if [[ $? -eq 0 ]]
            then
                echo "Port allowed successfully"
                echo
                echo "User succesfully allowed port $port/udp through the firewall" >>$LOG
                user_port      
            else
                echo "There was an error allowing the port through"
                echo "Would you like to try again? (yes/no)"
                echo
                read port_retry
                
                case $port_retry in
                yes)
                    user_port
                ;;
                no)
                    echo "Ok, skipping step..."
                    echo
                    echo "User skipped adding extra firewall rules after initial failure" >> $LOG
                ;;
                *)
                    echo "That was an invalid input, please try again"
                    echo
                    user_port
                ;;
                esac
            fi
        ;;
        *)
            echo "That was an invalid input, please try again"
            echo
            user_port
        ;;
        esac
    ;;    
    no)
        echo "Ok, if you want to add extra rules later you can do so by looking up the syntax for ufw"
        echo
    ;;
    *)
        echo "That was an invalid input, please try again"
        echo
        user_port
    ;;
    esac
}
if [ "$ufw_enabled" = "yes" ]
then
    user_port
fi

if [ "$ufw_enabled" = "yes" ]
then
    ufw enable > /dev/null
    if [[ $? -eq 0 ]]
    then
        echo "Firewall is active and enabled on system startup"
        echo
        echo "ufw configured and enabled successfully" >> $LOG
    fi
fi

## Part 5: Create new sudo user and send root to /sbin/nologin

## Part 6: Conclusion
echo >> $REPORT
echo >> $LOG

function conclusion ()
{
    echo "Script complete!"
    echo
    if [ "$enum" = "true" ]
    then
        echo "An Enumeration Report of this system was created in this folder"
        echo
        echo "A log file of what this script accomplished was also created in this folder"
        echo
        echo "What would you like to do? Please choose an option 1-3:"
        echo
        echo "  1) Read Enumeration Report"
        echo "  2) Read script log"
        echo "  3) Exit script"
        echo
        read final_opt

        case $final_opt in
        1)
            cat $REPORT
        ;;
        2)
            cat $LOG
        ;;
        3)
            exit
        ;;
        *)
            echo "That was an invalid input, please try again"
            conclusion
        ;;
        esac
    else
        echo "A log file of what this script accomplished was created in this folder"
        echo
        echo "Would you like to read it now? (yes/no)"
        echo
        read final_opt2

        case $final_opt2 in
        yes)
            cat $LOG
        ;;
        no)
            exit
        ;;
        *)
            "That was an invalid input, please try again"
            conclusion
        ;;
        esac
    fi
}
conclusion