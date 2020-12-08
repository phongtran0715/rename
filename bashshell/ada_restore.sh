#!/bin/bash
#Version 5.0

# default no set sudo password
PASSWORD=
# PASSWORD="your_sudo_password"

cd /ADA/AMM/
. ./.amm.sh
if [ ! -z "$PASSWORD" ]; then
	echo "$PASSWORD" | sudo -S /ADA/AMM/bin/mm_adm_device -s
else
	sudo /ADA/AMM/bin/mm_adm_device -s
fi

cd /ADA
cd Binary
. ./.ADA.sh
cd /mnt/restore/ADA-IN/

mkdir 0600
chmod 777 0600
cd 0600
if [ ! -z "$PASSWORD" ]; then
	echo "$PASSWORD" | sudo -S /ADA/Binary/Bin/ada_pax -v -x -d /dev/nst2:all
else
	sudo /ADA/Binary/Bin/ada_pax -v -x -d /dev/nst2:all
fi

echo "Done"