# Prerequisites  
> This script will work on most Linux-based systems.  
> If you are currently using dpkg or rpm, please install apt or yum.  
> Apk (Alpine) is already built in.  
> pacman package manager (Arch Linux) functionality coming soon.  

# Instructions  
> git clone https://gitlab.com/Omer.Tech/LinuxLockdown.git  
> chmod +x -R LinuxLockdown  
> ./LinuxLockdown/lockdown.sh  
> (Must be run as root or with sudo)  

# Functionality  
> If desired, installs Very Secure File Transfer Protocl (vsftp) to handle FTP  
> Installs secure vsftp configuration file  
> If desired, hardens SSH by importing secure configuration file  
> User can decide to only use keys, or combine using keys and passwords  
> If desired, install Uncomplicated Firewall (ufw)  
> Let's user choose which ports they wish to open  
> Implicitly denies any other protocols  
> Creates log file for script, and enumeration report  
> Prompts user to open either file, or just quit the script  

# Author  
> Omer Turhan  
> https://omer.tech  