#!/bin/bash

# Re-created on November 27, 2020 by Yasin Kaya (selengalp) 

QWAVE_PATH="/opt/qwave"
PPP_PATH="/opt/qwave/ppp_connection_manager"
devicename="ttyUSB3"

REPO_PATH="https://raw.githubusercontent.com/QWaveSystems/Catspi_PPP_Installer"
BRANCH=master
SOURCE_PATH="$REPO_PATH/$BRANCH/src"
SCRIPT_PATH="$REPO_PATH/$BRANCH/src/reconnect_scripts"
RECONNECT_SCRIPT_NAME="ppp_reconnect.sh"
MANAGER_SCRIPT_NAME="ppp_connection_manager.sh"
SERVICE_NAME="ppp_connection_manager.service"

YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[1;34m'
GREEN='\033[0;32m'
SET='\033[0m'

# Global Varibales
POWERUP_REQ=1
POWERUP_NOT_REQ=0

STATUS_GPRS=19
STATUS_CELL_IOT_APP=20
STATUS_CELL_IOT=23
STATUS_TRACKER=23

POWERKEY_GPRS=26
POWERKEY_CELL_IOT_APP=11
POWERKEY_CELL_IOT=24
POWERKEY_TRACKER=24


function colored_echo
{
	COLOR=${2:-$YELLOW}
	echo -e "$COLOR$1 ${SET}"
}


# Check Qwave path 
if [[ -e $QWAVE_PATH ]]; then
    colored_echo "Qwave path already exist!" ${SET}
else
    sudo mkdir $QWAVE_PATH
    colored_echo "Qwave path is created." ${SET}
fi

# Check PPP path 
if [[ -e $PPP_PATH ]]; then
    colored_echo "PPP path already exist!" ${SET}
else
    sudo mkdir $PPP_PATH
    colored_echo "PPP path is created." ${SET}
fi

colored_echo "Checking requirements..."

colored_echo "Updating headers..."
sudo apt-get update

colored_echo "Installing python3 if it is required..."
if ! [ -x "$(command -v python3)" ]; then
  sudo apt-get install python3 -y
  if [[ $? -ne 0 ]]; then colored_echo "Process failed" ${RED}; exit 1; fi
fi

colored_echo "Installing pip3 if it is required..."
if ! [ -x "$(command -v pip3)" ]; then
  sudo apt-get install python3-pip -y
  if [[ $? -ne 0 ]]; then colored_echo "Process failed" ${RED}; exit 1; fi
fi

colored_echo "Installing or upgrading atcom if it is required..."

pip3 install -U atcom
if [[ $? -ne 0 ]]; then colored_echo "Process failed" ${RED}; exit 1; fi

source ~/.profile
if [[ $? -ne 0 ]]; then colored_echo "Process failed" ${RED}; exit 1; fi


colored_echo "Downloading setup files..."

wget --no-check-certificate  $SOURCE_PATH/chat-connect -O chat-connect
if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

wget --no-check-certificate  $SOURCE_PATH/chat-disconnect -O chat-disconnect
if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

wget --no-check-certificate  $SOURCE_PATH/provider -O provider
if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

colored_echo "ppp and wiringpi (gpio tool) installing..."
apt-get install ppp wiringpi -y
if [[ $? -ne 0 ]]; then colored_echo "Process failed" ${RED}; exit 1; fi

# test wiringpi and fix if there is any issue
gpio readall | grep Oops > /dev/null
if [[ $? -ne 1 ]]; then 
	colored_echo "Known wiringpi issue is detected! Wiringpi is updating..."
	wget https://project-downloads.drogon.net/wiringpi-latest.deb
	sudo dpkg -i wiringpi-latest.deb
fi

colored_echo "What is your carrier APN?"
read carrierapn 

colored_echo "Your Input is : $carrierapn" ${GREEN} 

while [ 1 ]
do
	colored_echo "Does your carrier need username and password? [Y/n]"
	read usernpass
	
	colored_echo "You chose $usernpass" ${GREEN} 

	case $usernpass in
		[Yy]* )  

		while [ 1 ] 
        do 
        
        colored_echo "Enter username"
        read username

		colored_echo "Your Input is : $username" ${GREEN} 

        colored_echo "Enter password"
        read password

		colored_echo "Your Input is : $password" ${GREEN} 

        sed -i "s/noauth/#noauth\nuser \"$username\"\npassword \"$password\"/" provider
        break 
        done

        break;;
		
		[Nn]* )  break;;
		*)  colored_echo "Wrong Selection, Select among Y or n" ${RED};;
	esac
done

colored_echo "Your input is: $devicename" ${GREEN} 

if grep -q "ttyS0" <<<"$devicename"; then
	colored_echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-" ${BLUE}
	colored_echo "REMINDER!" ${BLUE}
	colored_echo "- Disable serial console and enable miniuart to use ttyS0 as the serial interface." ${SET}
	colored_echo "✔ If your ttyS0 (miniuart) port is enabled, press ENTER and continue to installation." ${SET}
	colored_echo "✘ If not, please follow the instructions to enable ttyS0 interface on Raspberry Pi" ${SET}
	echo -e "
	1. Start raspi-config: ${BLUE}sudo raspi-config${SET}.
	2. Select option 3 - ${BLUE}Interface Options${SET}.
	3. Select option P6 - ${BLUE}Serial Port${SET}.
	4. ${BLUE}At the prompt Would you like a login shell to be accessible over serial?${SET} answer ${BLUE}'No'${SET}
	5. ${BLUE}At the prompt Would you like the serial port hardware to be enabled?${SET} answer ${BLUE}'Yes'${SET}
	6. Exit raspi-config and ${BLUE}reboot${SET} the Pi for changes to take effect.
	"
	colored_echo "*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-" ${BLUE}
	echo
	echo -e "Press ${BLUE}ENTER${SET} key to continue to installation or press ${BLUE}CTRL^C${SET} to abort installation and enable ttyS0 serial interface."
	read -p "" ENTER

    colored_echo "Doing atcom configuration for ttyS0 serial..."
	# create atcom config
	echo port: "/dev/ttyS0" > configs.yml
	mv configs.yml $PPP_PATH
else
	# delete atcom config
	ls $PPP_PATH | grep configs.yml > /dev/null
	if [[ $? -eq 0 ]]; then rm $PPP_PATH/configs.yml; fi
fi

mkdir -p /etc/chatscripts

mv chat-connect /etc/chatscripts/
mv chat-disconnect /etc/chatscripts/

mkdir -p /etc/ppp/peers
sed -i "s/#APN/$carrierapn/" provider
sed -i "s/#DEVICE/$devicename/" provider
mv provider /etc/ppp/peers/provider

if ! (grep -q 'sudo route' /etc/ppp/ip-up ); then	
    echo "sudo route add default ppp0" >> /etc/ppp/ip-up	
fi

if ! (grep -q 'max_usb_current' /boot/config.txt ); then
    echo "max_usb_current=1" >> /boot/config.txt
fi

while [ 1 ]
do
	colored_echo "Do you want to activate auto connect/reconnect service at R.Pi boot up? [Y/n]"
	read auto_reconnect

	colored_echo "You chose $auto_reconnect" ${GREEN} 

	case $auto_reconnect in
		[Yy]* )    colored_echo "Downloading setup file..."
			  
			wget --no-check-certificate $SOURCE_PATH/$SERVICE_NAME
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			wget --no-check-certificate $SOURCE_PATH/functions.sh
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			wget --no-check-certificate $SOURCE_PATH/configs.sh
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			wget --no-check-certificate $SOURCE_PATH/configure_modem.sh
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			wget --no-check-certificate $SOURCE_PATH/$MANAGER_SCRIPT_NAME
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			# APN Configuration
			sed -i "s/SIM_APN/$carrierapn/" configure_modem.sh
			
			wget --no-check-certificate   $SCRIPT_PATH/reconnect_basehat -O $RECONNECT_SCRIPT_NAME
			if [[ $? -ne 0 ]]; then colored_echo "Download failed" ${RED}; exit 1; fi

			sed -i "s/POWERUP_FLAG/$POWERUP_NOT_REQ/" configure_modem.sh
			  
			  mv functions.sh $PPP_PATH
			  mv configs.sh $PPP_PATH
			  mv configure_modem.sh $PPP_PATH
			  mv $RECONNECT_SCRIPT_NAME $PPP_PATH
			  mv $MANAGER_SCRIPT_NAME $PPP_PATH
			  mv $SERVICE_NAME /etc/systemd/system/
			  
			  systemctl daemon-reload
			  systemctl enable $SERVICE_NAME
			  
			  break;;
			  
		[Nn]* )    echo -e "${YELLOW}To connect to internet run ${BLUE}\"sudo pon\"${YELLOW} and to disconnect run ${BLUE}\"sudo poff\" ${SET}"
			  break;;
		*)   colored_echo "Wrong Selection, Select among Y or n" ${RED};;
	esac
done

read -p "Press ENTER key to reboot" ENTER

colored_echo "Rebooting..." ${GREEN}
reboot
