#!/bin/bash
# Written by Kevin SJ Huang 2019/1/29

# This script is designed to run on RHEL7.

# This script is designed to test the following sensor threshold ONLY:
# Ambient Temp
# CPU DTS
# SysBrd 12V 5V 3.3V
# CMOS Battery
# Fan N Tach
# Use of other sensors will result in test incomplete.

# This script uses OOB only, please have the SUT BMC IP ready and run the script on a test client.
# In order to check for reboot event, SUT LAN IP is also mandatory.
# Test log will show if the SUT has been rebooted, but it won't be considered into pass/fail critiria.

### Script usage: $0 <Sensor_Name> <LAN_IP> <BMC_IP> <BMC_USER> <BMC_PWD>
### Missing any of the above parameter will result in test failures.
### If sensor name contains spaces, use double quotes or it will be errors.
### Make sure your LAN port is set to reconnect automatically after reboot.

ftp="10.32.37.19"
ftpusr="ESQ900"
ftppwd="1234"

BMC_IP=$3
BMC_USER=$4
BMC_PWD=$5
OS_IP=$6
OS_USER=$7
OS_PWD=$8

# Change here if your SUT login info is different
SUT_USER="root"
SUT_PWD="000000"

Initialization()
{
	sensorname="$1"
	lanip="$2"
	if [[ "$sensorname" != "Ambient Temp" && "$sensorname" != "CPU"[0-9]" DTS" && "$sensorname" != "Fan "[0-9]" Tach" && \
	"$sensorname" != "CMOS Battery" && "$sensorname" != "SysBrd 5V" && "$sensorname" != "SysBrd 3.3V" && \
	"$sensorname" != "SysBrd 12V" ]]; then
		echo "The sensor name you entered is not within the test scope of this script"
		echo "Exiting"
		exit 1
	else
		echo "The sensor name you entered is \"$sensorname\""
		echo 'Please check carefully for any incorrectness. *sensor name has to be exact match'
		echo "Press Ctrl + C to stop"
		sleep 5s
	fi
	echo "Checking if LAN IP $lanip is accessible..."
	ping $lanip -c 3 > /dev/null
	if [ $? -ne 0 ]; then
		echo "$lanip is inaccessible, please check the connection" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		exit 1
	else
		echo "OK" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	fi
	#check_sshpass
	#check_lan_auto_reconnect
}

check_sshpass()
{
	echo "Checking if sshpass has been installed..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	which sshpass
	if [ $? -eq 0 ]; then
		echo "sshpass has been installed" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	else
		echo "sshpass is not installed, installing now..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Disabling firewall daemon..."
		service firewalld stop
		service firewalld status |grep inactive
		[ $? -ne 0 ] && echo "Firewall disabling failed. Try to connect to FTP server anyway..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt \
		|| echo "Firewall disabled" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo;echo "Start to download sshpass from ESQ900 ST FTP" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		wget -P /root/ ftp://${ftpusr}:${ftppwd}@${ftp}/sshpass-1.06.tar.gz
		if [ $? -eq 0 ]; then
			echo "sshpass downloaded from FTP successfully" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		else
			echo "Download failed, sshpass installation stopped" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			return 1
		fi
		tar -C /root/ -xvf /root/sshpass-1.06.tar.gz
		chmod 777 -R /root/sshpass-1.06
		cd /root/sshpass-1.06
		./configure
		make install
		[ $? -eq 0 ] && echo "sshpass installed successfully" |tee -a ${dir}/"${0%.*}"_"${sensorname}"_log_"$datenow".txt \
		|| echo "sshpass may not installed correctly" |tee -a ${dir}/"${0%.*}"_"${sensorname}"_log_"$datenow".txt
		cd $dir
	fi
}

# Cannot solve ssh issue at the moment, this function is incomplete
check_lan_auto_reconnect()
{
	echo "Check if LAN is set to reconnect after reboot..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	sshpass -p "$SUT_PWD" ssh -o "StrictHostKeyChecking no" -tt ${SUT_USER}@$lanip
	if [ $? -ne 0 ]; then
		echo "Unable to ssh hence unable to check LAN auto reconnection." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Sensor threshold test that'd cause system reboot WILL fail." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Continue test without LAN check." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	else
		portname=`ifconfig |grep -B1 "$lanip" |awk 'FNR==1{print $1}'` ; portname=${portname%:}
		chmod 777 /etc/sysconfig/network-scripts/ifcfg-$portname
		oriconfig=`grep "ONBOOT" /etc/sysconfig/network-scripts/ifcfg-$portname |cut -d "=" -f2`
		if [ "$oriconfig" != "yes" ]; then
			echo "Setting auto reconnect..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			sed -i '/ONBOOT/s/no/yes/' /etc/sysconfig/network-scripts/ifcfg-$portname
			if [ $? -ne 0 ]; then
				echo "Somehow set failed, please change it manually in" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
				echo "/etc/sysconfig/network-scripts/ifcfg-${portname}" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
				echo "Change \"ONBOOT\" setting from no to yes" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
				echo "Exiting" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
				exit 1
			else
				echo "Set OK" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			fi
		else
			echo "Setting OK" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		fi
		exit
	fi
}

create_log()
{
	datenow="$(date +%Y%m%d%H%M%S)"
	touch "${0%.*}"_"${1}"_log_"$datenow".txt
}

verify()
{
	if [ $1 -ne 0 ]; then
		echo "Something went wrong!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		exit 1
	fi
}

iboob()
{	
	if [ -z "$BMC_IP" ] ; then
		echo "This script runs on OOB only" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "To use OOB mode, run $0 <Sensor_Name> <LAN_IP> <BMC_IP> <BMC_Username> <BMC_Password>"
		echo "Exiting"
		exit 1
	else 
		if [[ -z "$BMC_USER" || -z "$BMC_PWD" ]]; then
			echo "Missing IMM login info" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			exit 1
		fi
		string=" -I lanplus -H $BMC_IP -U $BMC_USER -P $BMC_PWD"
		echo "OOB mode  BMC IP: $BMC_IP" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Checking if $BMC_IP is accessible..."
		ping $BMC_IP -c 3 > /dev/null
		if [ $? -ne 0 ]; then
			echo "$BMC_IP is inaccessible, please check the connection" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			exit 1
		else
			echo "OK" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		fi
	fi
}

ipmitool_check()
{
	rpm -q ipmitool > /dev/null
	if [ $? -ne 0 ]; then
		echo "Seems that ipmitool is not installed on the system, exiting" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		exit 1
	fi
}

reboot_check()
{
	sleep 2s
	times=0
	ping -c1 $lanip |grep "ttl" > /dev/null
	while [[ $? -eq 0 && $times -le 30 ]]
	do
		[ $times -eq 30 ] && echo "SUT didn't reboot." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt ; reboot=0
		((times++))
		sleep 1s
		ping -c1 $lanip |grep "ttl" > /dev/null
	done
	ping -c1 $lanip |grep "ttl" > /dev/null
	if [ $? -ne 0 ]; then
		reboot=1
		echo "SUT shuted down/rebooted" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Waiting for SUT to get back online..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		sleep 60s
		ping -c1 $lanip |grep "ttl" > /dev/null
		while [[ $? -ne 0 && $times -le 1800 ]]
		do
			power=`ipmitool${string} power status |awk '{print $4}'`
			if [[ $times -eq 40 && "$power" = "off" ]]; then
				echo "SUT is still down, booting up manually now..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
				ipmitool${string} raw 0x0 0x2 0x1
			fi
			echo "Still waiting..."
			((times++))
			sleep 1s
			ping -c1 $lanip |grep "ttl" > /dev/null
		done
		ping -c1 $lanip |grep "ttl" > /dev/null
		if [ $? -eq 0 ]; then
			echo "SUT successfully rebooted and restored" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		else
			echo "SUT reboot failed, exiting" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
			exit 1
		fi
	fi
}

start_sensor_test()
{
	echo "Start $1 sensor $2 tests..."
	echo "Starting OEM sensor test command..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt

	ipmitool${string} raw 0x3a 0x17 0x0
	sensorstate=`ipmitool${string} raw 0x3a 0x17 0x4`
	if [[ $sensorstate -eq 01 ]]; then
		echo "OEM sensor test command started" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	else
		echo "Failed starting OEM sensor test command, exiting" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		exit 1
	fi

	ipmitool${string} raw 0x3a 0x17 0x5 "$sensorid"
	verify $?
	ipmitool${string} raw 0x3a 0x17 0x1 "$sensorid" 0x"$3" >> "${0%.*}"_"${sensorname}"_log_"$datenow".txt 2>&1
	reboot_check
	echo "Checking SEL now..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	ipmitool${string} sel list >> "${0%.*}"_"${sensorname}"_log_"$datenow".txt 2>&1
	sel_log=`ipmitool${string} sel list |grep "$sensorid" |grep "$4" |grep "Asserted"`
	if [ $? -eq 0 ]; then
		echo "$sel_log" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "$2 Assertion Test Passed!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	else
		echo "No $2 assertion log found" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "$2 Assertion Test Failed!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		check=1
	fi
	if [ $reboot -eq 0 ]; then
		echo "Ending OEM sensor test command..." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		ipmitool${string} raw 0x3a 0x17 0x2 2>&1 |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		sleep 10s
	fi
	sel_log=`ipmitool${string} sel list |grep "$sensorid" |grep "$4" |grep "Deasserted"`
	if [ $? -eq 0 ]; then
		echo "$sel_log" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Deassertion Test Passed!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	else
		echo "No deassertion log found" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		echo "Deassertion Test Failed!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
		check=1
	fi
}

echo "###Script usage: $0 <Sensor_Name> <LAN_IP> <BMC_IP> <BMC_USER> <BMC_PWD>"
echo '###Missing any of the above parameter will result in test failures.'
echo '###If sensor name contains spaces, use double quotes or it will be errors.'
echo '###Make sure your LAN port is set to reconnect automatically after reboot.'
sleep 3s

dir="$(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"

create_log "$1"

echo
echo 'Due to ssh issue, auto check sshpass and auto check lan reconnect function is off' |tee -a $"${0%.*}"_"${1}"_log_"$datenow".txt
echo "Please make sure your SUT\'s LAN port is set to auto reconnect after reboot" |tee -a $"${0%.*}"_"${1}"_log_"$datenow".txt
echo "Or the threshold tests that would cause system reboot WILL fail" |tee -a $"${0%.*}"_"${1}"_log_"$datenow".txt
echo
sleep 3s

Initialization "$1" "$2"

iboob
ipmitool_check

echo "Getting Sensor ID..." |tee -a $"${0%.*}"_"${1}"_log_"$datenow".txt
ipmitool${string} sdr get "$sensorname" >> "${0%.*}"_"${1}"_log_"$datenow".txt 2>&1
sensorid=`ipmitool${string} sdr get "$sensorname" |grep "Sensor ID" |cut -d "(" -f2 |cut -d ")" -f1`
if [ -z $sensorid ]; then
	echo "Please check the BMC SPEC"
	exit 1
fi
[[ ${#sensorid} -eq 3 ]] && sensorid="${sensorid:0:2}0${sensorid:2}"
echo "The \"$sensorname\" sensor ID on this platform is $sensorid" |tee -a "${0%.*}"_"${1}"_log_"$datenow".txt
sleep 3s

echo "Clearing BMC SEL..." |tee -a "${0%.*}"_"${1}"_log_"$datenow".txt
ipmitool${string} sel clear 2>&1 |tee -a "${0%.*}"_"${1}"_log_"$datenow".txt
sleep 5s

echo "Begin sensor test..." |tee -a "${0%.*}"_"${1}"_log_"$datenow".txt

lnc=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $2}'`
lc=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $3}'`
lnr=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $4}'`
unc=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $5}'`
uc=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $6}'`
unr=`ipmitool${string} raw 0x04 0x27 "$sensorid" |awk '{print $7}'`
check=0

case $sensorname in
	'Ambient Temp')
		start_sensor_test "$sensorname" "UNC" "$unc" "Upper Non-cri"
		start_sensor_test "$sensorname" "UC" "$uc" "Upper Cri"
		start_sensor_test "$sensorname" "UNR" "$unr" "Upper Non-rec"
		;;
	'CPU'?' DTS')
		start_sensor_test "$sensorname" "UC" "$uc" "Upper Cri"
		start_sensor_test "$sensorname" "UNR" "$unr" "Upper Non-rec"
		;;
	'SysBrd '*'V')
		start_sensor_test "$sensorname" "UC" "$uc" "Upper Cri"
		start_sensor_test "$sensorname" "LC" "$lc" "Lower Cri"
		;;
	'CMOS Battery')
		start_sensor_test "$sensorname" "LNC" "$lnc" "Lower Non-cri"
		start_sensor_test "$sensorname" "LC" "$lc" "Lower Cri"
		;;
	'Fan '?' Tach')
		start_sensor_test "$sensorname" "LC" "$lc" "Lower Cri"
	;;
esac

if [ $check -eq 0 ]; then
	echo "$sensorname threshold sensor tests PASSED!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
else
	echo "$sensorname threshold sensor tests FAILED!" |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
	echo "Please check the log." |tee -a "${0%.*}"_"${sensorname}"_log_"$datenow".txt
fi
