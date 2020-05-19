#!/bin/bash

##################################################
#version 3.2 from 11 august 2017 year
#http://help.ubuntu.ru/wiki/canon_capt
#http://forum.ubuntu.ru/index.php?topic=189049.0
##################################################

#check super user
[ $USER != 'root' ] && exec sudo "$0"

#user which we used to log in to system
LOGIN_USER=$(logname)
[ -z "$LOGIN_USER" ] && LOGIN_USER=$(who | head -1 | awk '{print $1}')

#desktop folder path
if [ -f ~/.config/user-dirs.dirs ]; then 
	source ~/.config/user-dirs.dirs
else
	XDG_DESKTOP_DIR="$HOME/Desktop"
fi

#driver version
DRIVER_VERSION='2.71-1'
DRIVER_VERSION_COMMON='3.21-1'

#links to driver packages
declare -A URL_DRIVER=([amd64_common]='https://github.com/ikr0m/canon-driver/raw/master/files/cndrvcups-common_3.21-1_amd64_0Byemcyi98JRjcXE1YWE0VjVDalE.deb' \
[amd64_capt]='https://github.com/ikr0m/canon-driver/raw/master/files/cndrvcups-capt_2.71-1_amd64_0Byemcyi98JRjaWM2QzhVWF9MRGM.deb' \
[i386_common]='https://github.com/ikr0m/canon-driver/raw/master/files/cndrvcups-common_3.21-1_i386_0Byemcyi98JRjeEs5UG9ZdTNBaXc.deb' \
[i386_capt]='https://github.com/ikr0m/canon-driver/raw/master/files/cndrvcups-capt_2.71-1_i386_0Byemcyi98JRjcWRrQ2dKZ1JyTUU.deb')

#links to utility autoshutdowntool
declare -A URL_ASDT=([amd64]='https://github.com/ikr0m/canon-driver/raw/master/files/autoshutdowntool_1.00-1_amd64_deb_0Byemcyi98JRjc0s2YlJVZ0xBckk.tar.gz' \
[i386]='https://github.com/ikr0m/canon-driver/raw/master/files/autoshutdowntool_1.00-1_i386_deb_0Byemcyi98JRjdzFlWjVnbGpBMFU.tar.gz')

#corresponding ppd files and printer models
declare -A LASERSHOT=([LBP-810]=1120 [LBP-1120]=1120 [LBP-1210]=1210 \
[LBP2900]=2900 [LBP3000]=3000 [LBP3010]=3050 [LBP3018]=3050 [LBP3050]=3050 \
[LBP3100]=3150 [LBP3108]=3150 [LBP3150]=3150 [LBP3200]=3200 [LBP3210]=3210 \
[LBP3250]=3250 [LBP3300]=3300 [LBP3310]=3310 [LBP3500]=3500 [LBP5000]=5000 \
[LBP5050]=5050 [LBP5100]=5100 [LBP5300]=5300 [LBP6000]=6018 [LBP6018]=6018 \
[LBP6020]=6020 [LBP6020B]=6020 [LBP6200]=6200 [LBP6300n]=6300n [LBP6300]=6300 \
[LBP6310]=6310 [LBP7010C]=7018C [LBP7018C]=7018C [LBP7200C]=7200C [LBP7210C]=7210C \
[LBP9100C]=9100C [LBP9200C]=9200C)

#sort printer names
NAMESPRINTERS=$(echo "${!LASERSHOT[@]}" | tr ' ' '\n' | sort -n -k1.4)

#models list which support autoshutdown utility
declare -A ASDT_SUPPORTED_MODELS=([LBP6020]='MTNA002001 MTNA999999' \
[LBP6020B]='MTMA002001 MTMA999999' [LBP6200]='MTPA00001 MTPA99999' \
[LBP6310]='MTLA002001 MTLA999999' [LBP7010C]='MTQA00001 MTQA99999' \
[LBP7018C]='MTRA00001 MTRA99999' [LBP7210C]='MTKA002001 MTKA999999')

#operating system architecture
if [ "$(uname -m)" == 'x86_64' ]; then
  ARCH='amd64'
else
  ARCH='i386'
fi

#detect system initialization
if [[ $(ps -p1 | grep systemd) ]]; then
	INIT_SYSTEM='systemd'
else
	INIT_SYSTEM='upstart'
fi

#do working directory which this script located
cd "$(dirname "$0")"

function valid_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        ip=($(echo "$ip" | tr '.' ' '))
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function check_error() {
	if [ $2 -ne 0 ]; then
		case $1 in
			'WGET') echo "Error while downloading file $3"
				[ -n "$3" ] && [ -f "$3" ] && rm "$3";;
			'PACKAGE') echo "Error while installing packet $3";;
			*) echo 'Error';;
		esac
		echo 'Press any key to exit'
		read -s -n1
		exit 1
	fi
}

function canon_unistall() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		installed_model=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$installed_model" ]; then
			echo "Printer found $installed_model"
			echo "Finished captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Stopping daemon ccpd'
			service ccpd stop
			echo 'Deleting printer from ccpd daemon file settings'
			ccpdadmin -x $installed_model
			echo 'Deleting printer from CUPS'
			lpadmin -x $installed_model
		fi
	fi
	echo 'Deleting driver packages'
	dpkg --purge cndrvcups-capt
	dpkg --purge cndrvcups-common
	echo 'Deleting not used libraries and packages'
	apt-get -y autoremove
	echo 'Deleting settings'
	[ -f /etc/init/ccpd-start.conf ] && rm /etc/init/ccpd-start.conf
	[ -f /etc/udev/rules.d/85-canon-capt.rules ] && rm /etc/udev/rules.d/85-canon-capt.rules
	[ -f "${XDG_DESKTOP_DIR}/captstatusui.desktop" ] && rm "${XDG_DESKTOP_DIR}/captstatusui.desktop"
	[ -f /usr/bin/autoshutdowntool ] && rm /usr/bin/autoshutdowntool
	[ $INIT_SYSTEM == 'systemd' ] && update-rc.d -f ccpd remove
	echo 'Finished deleting'
	echo 'Press any key to exit'
	read -s -n1
	return 0
}

function canon_install() {
	echo
	PS3='Choose printer. Enter desired number and press Enter: '
	select NAMEPRINTER in $NAMESPRINTERS
	do
		[ -n "$NAMEPRINTER" ] && break
	done
	echo "Choosen printer: $NAMEPRINTER"
	echo
	PS3='How is the printer connected to the computer? Enter the desired number and press Enter: '
	select CONECTION in 'Via USB' 'Via LAN (LAN, NET)'
	do
		if  [ "$REPLY" == "1" ]; then
			CONECTION="usb"
			while true
			do	
				#looking for a device connected to the USB port
				NODE_DEVICE=$(ls -1t /dev/usb/lp* 2> /dev/null | head -1)
				if [ -n "$NODE_DEVICE" ]; then
					#determine the serial number of the printer
					PRINTER_SERIAL=$(udevadm info --attribute-walk --name=$NODE_DEVICE | sed '/./{H;$!d;};x;/ATTRS{product}=="Canon CAPT USB \(Device\|Printer\)"/!d;' |  awk -F'==' '/ATTRS{serial}/{print $2}')
					#if the serial number is found, then the Canon printer found is the device
					[ -n "$PRINTER_SERIAL" ] && break
				fi
				echo -ne "Turn on the printer\r"
				sleep 2
			done
			PATH_DEVICE="/dev/canon$NAMEPRINTER"
			break
		elif [ "$REPLY" == "2" ]; then
			CONECTION="lan"
			read -p 'Enter the IP address of the printer: ' IP_ADDRES
			until valid_ip "$IP_ADDRES"
			do
				echo 'Incorrect IP address format, enter four decimal numbers with a value'
				echo -n 'от 0 до 255, разделённых точками: '
				read IP_ADDRES
			done
			PATH_DEVICE="net:$IP_ADDRES"
			echo 'Turn on the printer and press any key'
			read -s -n1
			sleep 5
			break
		fi		
	done
	echo 'Driver installation'
	COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
	CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
	if [ ! -f $COMMON_FILE ]; then		
		sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
		check_error WGET $? $COMMON_FILE
	fi
	if [ ! -f $CAPT_FILE ]; then
		sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
		check_error WGET $? $CAPT_FILE
	fi
	apt-get -y update
	apt-get -y install libglade2-0
	check_error PACKAGE $? libglade2-0
	echo 'Installing a common module for the CUPS driver'
	dpkg -i $COMMON_FILE
	check_error PACKAGE $? $COMMON_FILE
	echo 'Installing the CAPT Printer Driver Module'
	dpkg -i $CAPT_FILE
	check_error PACKAGE $? $CAPT_FILE
	#replacing file contents /etc/init.d/ccpd
	echo '#!/bin/bash
# startup script for Canon Printer Daemon for CUPS (ccpd)
### BEGIN INIT INFO
# Provides:          ccpd
# Required-Start:    $local_fs $remote_fs $syslog $network $named
# Should-Start:      $ALL
# Required-Stop:     $syslog $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Description:       Start Canon Printer Daemon for CUPS
### END INIT INFO

DAEMON=/usr/sbin/ccpd
case $1 in
	start)
		start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
		;;
	stop)
		start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
		;;	
	status)
		echo "${DAEMON}:" $(pidof ${DAEMON})
		;;
	restart)
		while true
		do
			start-stop-daemon --stop --quiet --oknodo --retry TERM/30/KILL/5 --exec ${DAEMON}
			start-stop-daemon --start --quiet --oknodo --exec ${DAEMON}
			for (( i = 1 ; i <= 5 ; i++ )) 
			do
				sleep 1
				set -- $(pidof ${DAEMON})
				[ -n "$1" -a -n "$2" ] && exit 0
			done
		done
		;;
	*)
		echo "Usage: ccpd {start|stop|status|restart}"
		exit 1
		;;
esac
exit 0' > /etc/init.d/ccpd
	#installation of management utilities AppArmor
	apt-get -y install apparmor-utils
	#setting the AppArmor profile to sparing mode for cupsd
	aa-complain /usr/sbin/cupsd
	echo 'Restarting CUPS'
	service cups restart
	echo 'Installation of 32-bit libraries necessary for'
	echo '64-bit printer driver'
	if [ $ARCH == 'amd64' ]; then
		apt-get -y install libatk1.0-0:i386 libcairo2:i386 libgtk2.0-0:i386 libpango1.0-0:i386 libstdc++6:i386 libpopt0:i386 libxml2:i386 libc6:i386
		check_error PACKAGE $?
	fi
	echo 'Installing the printer in CUPS'
	/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
	echo "Installing $NAMEPRINTER, printer, the default printer"
	/usr/sbin/lpadmin -d $NAMEPRINTER
	echo 'Registering the printer in the ccpd daemon configuration file'
	/usr/sbin/ccpdadmin -p $NAMEPRINTER -o $PATH_DEVICE
	#check printer setup
	installed_printer=$(ccpdadmin | grep $NAMEPRINTER | awk '{print $3}')
	if [ -n "$installed_printer" ]; then
		if [ "$CONECTION" == "usb" ]; then
			echo 'Creating a rule for the printer'
			#we will make a rule that will provide an alternative name (symbolic link) to our printer so that it does not depend on the changing values of lp0, lp1, ...
			echo 'KERNEL=="lp[0-9]*", SUBSYSTEMS=="usb", ATTRS{serial}=='$PRINTER_SERIAL', SYMLINK+="canon'$NAMEPRINTER'"' > /etc/udev/rules.d/85-canon-capt.rules
			#updating rules 
			udevadm control --reload-rules
			#checking the created rule
			until [ -e $PATH_DEVICE ]
			do
				echo -ne "Turn off the printer, wait 2 seconds, then turn on the printer\r"
				sleep 2
			done
		fi
		echo -e "\e[2KStart ccpd"
		service ccpd restart
		#ccpd startup
		if [ $INIT_SYSTEM == 'systemd' ]; then
			update-rc.d ccpd defaults
		else
			echo 'description "Canon Printer Daemon for CUPS (ccpd)"
author "LinuxMania <customer@linuxmania.jp>"
start on (started cups and runlevel [2345])
stop on runlevel [016]
expect fork
respawn
exec /usr/sbin/ccpd start' > /etc/init/ccpd-start.conf	
		fi
		#create captstatusui launch button on the desktop
		echo '#!/usr/bin/env xdg-open
[Desktop Entry]
Version=1.0
Name=captstatusui
GenericName=Status monitor for Canon CAPT Printer
Exec=captstatusui -P '$NAMEPRINTER'
Terminal=false
Type=Application
Icon=/usr/share/icons/Humanity/devices/48/printer.svg' > "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chmod 775 "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		chown $LOGIN_USER:$LOGIN_USER "${XDG_DESKTOP_DIR}/captstatusui.desktop"
		#install auto-shutdown utility for supported printer models
		if [[ "${!ASDT_SUPPORTED_MODELS[@]}" =~ "$NAMEPRINTER" ]]; then
			SERIALRANGE=(${ASDT_SUPPORTED_MODELS[$NAMEPRINTER]})
			SERIALMIN=${SERIALRANGE[0]}
			SERIALMAX=${SERIALRANGE[1]}	
			if [[ ${#PRINTER_SERIAL} -eq ${#SERIALMIN} && $PRINTER_SERIAL > $SERIALMIN && $PRINTER_SERIAL < $SERIALMAX || $PRINTER_SERIAL == $SERIALMIN || $PRINTER_SERIAL == $SERIALMAX ]]; then
				echo "Install autoshutdowntool"
				ASDT_FILE=autoshutdowntool_1.00-1_${ARCH}_deb.tar.gz
				if [ ! -f $ASDT_FILE ]; then		
					wget -O $ASDT_FILE ${URL_ASDT[$ARCH]}
					check_error WGET $? $ASDT_FILE
				fi
				tar --gzip --extract --file=$ASDT_FILE --totals --directory=/usr/bin
			fi
		fi	
		#Start captstatusui
		if [[ -n "$DISPLAY" ]] ; then
			sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
			sleep 5
		fi
		echo 'Installation completed. Press any key to exit'
		read -s -n1
		exit 0
	else
		echo "Принтер $NAMEPRINTER не установлен"
		echo 'Нажмите любую клавишу для выхода'
	 	read -s -n1
		exit 1
	fi
}

function canon_update() {
	if [ -f /usr/sbin/ccpdadmin ]; then
		NAMEPRINTER=$(ccpdadmin | grep LBP | awk '{print $3}')
		if [ -n "$NAMEPRINTER" ]; then
			echo "Found printer $NAMEPRINTER"
			SETUP_DRIVER_VERSION=$(dpkg -l | grep cndrvcups-capt | awk '{print $3}')
			echo "Installed driver version: $SETUP_DRIVER_VERSION"
			echo "Version of driver to be installed: $DRIVER_VERSION"			
			dpkg --compare-versions $DRIVER_VERSION lt $SETUP_DRIVER_VERSION
			if [ $? -eq 0 ]; then
				echo 'The version of the driver to be installed is less than the version of the installed one.
The update will not continue. Press any key to exit'
				read -s -n1
				exit 1
			fi
			echo "Completion of the captstatusui"
			killall captstatusui 2> /dev/null
			echo 'Installing daemon ccpd'
			service ccpd stop
			echo 'Removing a printer from CUPS'
			lpadmin -x $NAMEPRINTER
			#updating driver...'
			COMMON_FILE=cndrvcups-common_${DRIVER_VERSION_COMMON}_${ARCH}.deb
			CAPT_FILE=cndrvcups-capt_${DRIVER_VERSION}_${ARCH}.deb
			if [ ! -f $COMMON_FILE ]; then		
				sudo -u $LOGIN_USER wget -O $COMMON_FILE ${URL_DRIVER[${ARCH}_common]}
				check_error WGET $? $COMMON_FILE
			fi
			if [ ! -f $CAPT_FILE ]; then
				sudo -u $LOGIN_USER wget -O $CAPT_FILE ${URL_DRIVER[${ARCH}_capt]}
				check_error WGET $? $CAPT_FILE
			fi
			echo 'Updating the general module for the driver CUPS'
			dpkg -i $COMMON_FILE
			check_error PACKAGE $? $COMMON_FILE
			echo 'Updating the printer driver module CAPT'
			dpkg -i $CAPT_FILE
			check_error PACKAGE $? $CAPT_FILE
			echo 'Restart CUPS'
			service cups restart
			echo 'Setting up the printer in CUPS'
			/usr/sbin/lpadmin -p $NAMEPRINTER -P /usr/share/cups/model/CNCUPSLBP${LASERSHOT[$NAMEPRINTER]}CAPTK.ppd -v ccp://localhost:59687 -E
			echo "Setting up printer $NAMEPRINTER, as default printer"
			/usr/sbin/lpadmin -d $NAMEPRINTER
			if [[ -n "$DISPLAY" ]] ; then			
				echo 'Start captstatusui'
				while true
				do
					sleep 1
					set -- $(pidof /usr/sbin/ccpd)
					if [ -n "$1" -a -n "$2" ]; then
						sudo -u $LOGIN_USER nohup captstatusui -P $NAMEPRINTER > /dev/null 2>&1 &
						sleep 5
						break
					fi
				done
			fi
			echo "The driver is updated. Press any key to exit"
	 		read -s -n1
			exit 0
		fi
	fi
	echo "Printers from the Canon LBP series are not installed"
	echo 'Press any key to exit'
	read -s -n1
	exit 1
}

function canon_help {
	clear
	echo 'Installation Notes
If you have already taken any steps to install this printer series,
in the current system, then before starting the installation, you should cancel these actions.
If there are no driver packages, they are automatically downloaded from the Internet.
to the script folder. Printers LBP-810, LBP-1210 connect via the USB port connector
To update the driver, first delete the old version through the script, then
install the new one also through the script.
Printing Issues
If the printer stops printing, start captstatusui through the start button
on the desktop or in the terminal with the command: captstatusui -P <printer name>
The captstatusui window displays a message about the current status of the printer if
an error occurs, its description is displayed. Here you can try to press the button
"Resume Job" to continue printing or the "Cancel Job" button to cancel the job.
If this does not help, then run the canon_restart.sh script

printer setup command: cngplp
advanced settings, command: captstatusui -P <printer name>
auto power off setting (not for all models): autoshutdowntool
Remarks and errors write to coden@mail.ru or
to the forum http://forum.ubuntu.ru/index.php?topic=189049.0
To log the installation process, run the script like this:
logsave log.txt ./canon_lbp_setup.sh
'
}

clear
echo 'Driver installation Linux CAPT Printer Driver v'${DRIVER_VERSION}' for printers Canon LBP
on Ubuntu 12.04, 12.10, 13.04, 13.10, 14.04, 14.10, 15.04, 15.10, 16.04 32-bit and 64-bit architecture
Supported Printers:'
echo "$NAMESPRINTERS" | sed ':a; /$/N; s/\n/, /; ta' | fold -s

PS3='Action selection. Enter the desired number and press Enter: '
select opt in 'Installation' 'Removal' 'Help' 'Exit'
do
	if [ "$opt" == 'Installation' ]; then
		canon_install
		break
	elif [ "$opt" == 'Removal' ]; then
		canon_unistall
		break
#	elif [ "$opt" == 'Обновление' ]; then
#		canon_update
#		break	
	elif [ "$opt" == 'Help' ]; then
		canon_help
	elif [ "$opt" == 'Exit' ]; then
		break
	fi
done
