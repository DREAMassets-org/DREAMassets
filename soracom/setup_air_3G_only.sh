#!/bin/bash
# setup_air.sh
# populate udev rules and interface for SORACOM Air
setup_config_files()
{
	if ! grep "iface wwan0" /etc/network/interfaces &> /dev/null
	then
		echo "Adding network interface 'wwan0'."
		cat << EOF >> /etc/network/interfaces
allow-hotplug wwan0
iface wwan0 inet wvdial
EOF
	fi

	if [ -f /etc/udev/rules.d/30-soracom.rules ]
	then
		return 0 # nothing to do
	fi
	echo "Adding udev rules for modem detection."
	cat << EOF > /etc/udev/rules.d/30-soracom.rules
# FS01BU
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1c9e", ATTRS{idProduct}=="98ff", RUN+="/usr/sbin/usb_modeswitch -v 1c9e -p 98ff -M '55534243123456780000000080000606f50402527000000000000000000000'"
ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="1c9e", ATTRS{idProduct}=="98ff", RUN+="/bin/bash -c 'modprobe option && echo 1c9e 6801 > /sys/bus/usb-serial/drivers/option1/new_id'"

KERNEL=="ttyUSB*", ATTRS{../idVendor}=="1c9e", ATTRS{../idProduct}=="6801", ATTRS{bNumEndpoints}=="02", ATTRS{bInterfaceNumber}=="02", SYMLINK+="modem", ENV{SYSTEMD_WANTS}="ifup@wwan0.service"

# AK-020
ACTION=="add", ATTRS{idVendor}=="15eb", ATTRS{idProduct}=="a403", RUN+="/usr/sbin/usb_modeswitch --std-eject --default-vendor 0x15eb --default-product 0xa403 --target-vendor 0x15eb --target-product 0x7d0e"
ACTION=="add", ATTRS{idVendor}=="15eb", ATTRS{idProduct}=="7d0e", RUN+="/sbin/modprobe usbserial vendor=0x15eb product=0x7d0e"

KERNEL=="ttyUSB*", ATTRS{../idVendor}=="15eb", ATTRS{../idProduct}=="7d0e", ATTRS{bNumEndpoints}=="03", ATTRS{bInterfaceNumber}=="02", SYMLINK+="modem", ENV{SYSTEMD_WANTS}="ifup@wwan0.service"

# MS2131 or MS2372
ACTION=="add", ATTR{idVendor}=="12d1", ATTR{idProduct}=="14fe", RUN+="usb_modeswitch '/%k'"
KERNEL=="ttyUSB*", ATTRS{../idVendor}=="12d1", ATTRS{../idProduct}=="1506", ATTRS{bNumEndpoints}=="03", ATTRS{bInterfaceNumber}=="00", SYMLINK+="modem", ENV{SYSTEMD_WANTS}="ifup@wwan0.service"
EOF
        udevadm control --reload-rules
}

# Mike added the AT command below to disable 2G and make the modem WCDMA only
# Mike and Kenta modified the original setup_air.sh on Fri Dec 7th 2018 
# the old Init3 is now Init4; the new Init3 sets 3G only: 
# Init3 = AT^SYSCFG=14,2,3FFFFFFF,1,2
setup_wvdial()
{
	cat > /etc/wvdial.conf << EOF
[Dialer Defaults]
Init1 = AT+CFUN=1
Init2 = ATZ
Init3 = AT^SYSCFG=14,2,3FFFFFFF,1,2
Init4 = AT+CGDCONT=1,"IP","$1"
Dial Attempts = 3
Stupid Mode = 1
Modem Type = Analog Modem
Dial Command = ATD
Stupid Mode = yes
Baud = 460800
New PPPD = yes
ISDN = 0
APN = $1
Phone = *99***1#
Username = $2
Password = $3
Carrier Check = no
Auto DNS = 1
Check Def Route = 1
EOF
	grep replacedefaultroute /etc/ppp/peers/wvdial &> /dev/null || echo replacedefaultroute >> /etc/ppp/peers/wvdial
}

initialize_modem()
{
	for x in 1c9e:98ff 1c9e:6801 15eb:a403 15eb:7d0e 12d1:14fe 
	do
		if (lsusb | grep $x > /dev/null)
		then
			echo Found un-initilized modem. Trying to initialize it ...
			eval $(echo $x | tr : \  | awk '{print "udevadm trigger -c add --attr-match=idVendor="$1" --attr-match=idProduct="$2}')
			return 0
		fi
	done
	return 1
}

configure_apn()
{
	usb-devices | grep HUAWEI_MOBILE > /dev/null || return 0
	echo found HUAWEI LTE USB donelge. Configuring APN ...
	if [ ! -x /usr/bin/expect -o ! -x /usr/bin/cu ]
	then
		echo Installling required packages.
	        apt-get install -y --no-install-recommends cu expect || exit 1
	fi
	if [ -e /dev/ttyUSB0 ]
	then
		chmod 666 /dev/ttyUSB0
		sleep 1
		expect <<EOS || return 1
spawn cu -l /dev/ttyUSB0
sleep 1
expect "Connected."
send "\rATE1\r"
send "AT+CGDCONT?\r"
expect "OK"
sleep 1
send "AT+CGDCONT=0,\"IP\",\"$1\"\r"
expect "OK"
sleep 1
send "AT+CGDCONT=1,\"IP\",\"$1\"\r"
expect "OK"
sleep 1
send "AT+CGDCONT?\r"
expect "OK"
sleep 1
send "ATE0\r"
expect "OK"
exit
EOS
		echo re-plug modem or reboot OS
		return 0
	else
		echo could not find /dev/ttyUSB0. try OS reboot.
		return 1
	fi
}

echo --- 1. Check required packages

if [ $UID != 0 ]
then
	echo please execute as root or use sudo command.
	exit 1
elif [ ! -x /usr/bin/wvdial ]
then
	echo 'wvdial is not installed! installing wvdial...'
	echo
	apt-get update && apt-get install -y --no-install-recommends wvdial || exit 1
	echo
	echo "# please ignore message above, as /etc/wvdial.conf will be created soon."
	echo
fi

echo ok.
echo

echo --- 2. Patching /lib/systemd/system/ifup@.service
sed -ie 's/^After=sys-subsystem-net-devices-%i.device$/# After=sys-subsystem-net-devices-%i.device/' /lib/systemd/system/ifup@.service || exit 1
echo ok.
echo

echo --- 3. Generate config files

[ "$1" = "" ] && apn=soracom.io || apn=$1
[ "$2" = "" ] && user=sora || user=$2
[ "$3" = "" ] && pass=sora || pass=$3

setup_config_files
setup_wvdial $apn $user $pass

echo ok.
echo

echo --- 4. Initialize Modem
initialize_modem
configure_apn $apn || configure_apn $apn || configure_apn $apn
if [ $? = 0 ]
then
	echo ok.
else
	echo NG! please retry.
	exit 1
fi
cat <<EOF
Now you are all set.

Tips:
 - When you plug your usb-modem, it will automatically connect.
 - If you want to disconnect manually or connect again, you can use 'sudo ifdown wwan0' / 'sudo ifup wwan0' commands.
 - Or you can just execute 'sudo wvdial'.
EOF
