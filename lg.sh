#!/bin/bash
#This is based on Looking Glass quickstart guide:
#https://looking-glass.hostfission.com/wiki/Installation
#Fedora selinux issues resolved thanks to:
#https://forum.level1techs.com/t/vfio-in-2019-fedora-workstation-general-guide-though-branch-draft/145106/41

#Making sure that the looking glass folder is present
if ! [ -d looking*/client ]
then
echo "Please copy the Looking Glass folder into this folder"
exit
fi


#Making sure this script runs with elevated privileges
if [ $(id -u) -ne 0 ]
	then
		echo "Please run this as root!" 
		exit 1
fi



echo "Installing dependencies"
apt-get install binutils-dev cmake fonts-dejavu-core libfontconfig-dev gcc g++ pkg-config libegl-dev libgl-dev libgles-dev libspice-protocol-dev nettle-dev libx11-dev libxcursor-dev libxi-dev libxinerama-dev libxpresent-dev libxss-dev libxkbcommon-dev libwayland-dev wayland-protocols

#Installing required packages for each distro
DISTRO=`cat /etc/*release | grep DISTRIB_ID | cut -d '=' -f 2`
FEDORA=`cat /etc/*release |  head -n 1 | cut -d ' ' -f 1`

if [ "$DISTRO" == "Ubuntu" ] || [ "$DISTRO" == "Pop" ] || [ "$DISTRO" == "LinuxMint" ]
	then
apt-get install binutils-dev cmake fonts-freefont-ttf libsdl2-dev libsdl2-ttf-dev libspice-protocol-dev libfontconfig1-dev libx11-dev nettle-dev  wayland-protocols -y
elif [ "$DISTRO" == "Arch" ]
	then
pacman -Syu binutils sdl2 sdl2_ttf libx11 libxpresent nettle fontconfig cmake spice-protocol make pkg-config gcc gnu-free-fonts
elif [ "$DISTRO" == "ArcoLinux" ]
	then
pacman -Syu binutils sdl2 sdl2_ttf libx11 libxpresent nettle fontconfig cmake spice-protocol make pkg-config gcc gnu-free-fonts

elif [ "$DISTRO" == "ManjaroLinux" ]
	then
pacman -Syu binutils sdl2 sdl2_ttf libx11 libxpresent nettle fontconfig cmake spice-protocol make pkg-config gcc gnu-free-fonts
elif [ "$FEDORA" == "Fedora" ]
	then
	dnf install make cmake binutils-devel SDL2-devel SDL2_ttf-devel nettle-devel spice-protocol fontconfig-devel libX11-devel egl-wayland-devel wayland-devel mesa-libGLU-devel mesa-libGLES-devel mesa-libGL-devel mesa-libEGL-devel libXfixes-devel libXi-devel
	else
echo "This script does not support your current distribution. Only Fedora, Manjaro, PopOS and Ubuntu are supported!"
echo "You can still install Looking Glass manually!"
	exit
fi


VIRT_USER=`logname`

if [ $1 != "--no-confirm" ]
then
	#Identifying user to set permissions
	echo 
	echo "User: $VIRT_USER will be using Looking Glass on this PC. "
	echo "If that's correct, press (y) otherwise press (n) and you will be able to specify the user."
	echo 
	echo "y/n?"
	read USER_YN


	#Allowing the user to manually edit the Looking Glass user
	if [ $USER_YN = 'n' ] || [ $USER_YN = 'N' ]
	then
	USER_YN='n'
		while [ '$USER_YN' = "n" ]; do
			echo "Enter the new username: "
			read VIRT_USER


			echo "Is $VIRT_USER correct (y/n)?"
			read USER_YN
		done
	fi
	echo User $VIRT_USER selected. Press any key to continue:
	read ANY_KEY
fi

# Looking Glass requirements: /dev/shm/looking_glass needs to be created on startup
echo "touch /dev/shm/looking-glass && chown $VIRT_USER:kvm /dev/shm/looking-glass && chmod 660 /dev/shm/looking-glass" > lg_start.sh

#Create a systemd service to initialize the GPU on startup
cp lg_start.service /etc/systemd/system/lg_start.service
chmod 644 /etc/systemd/system/lg_start.service

mv lg_start.sh /usr/bin/lg_start.sh
chmod +x /usr/bin/lg_start.sh

systemctl enable lg_start.service

systemctl start lg_start.service

if [ -a looking*.tar.gz ]
then 
mv looking*.tar.gz tar_lg.tar.gz
fi

#Compiling Looking Glass
cd looking*
mkdir client/build
cd client/build
cmake ../
make
chown $VIRT_USER looking-glass-client

#SELinux on Fedora prevents it from working
if [ "$FEDORA" == "Fedora" ]
then
echo "Please be patient"
sudo ausearch -c 'qemu-system-x86' --raw | audit2allow -M my-qemusystemx86
sudo semodule -X 300 -i my-qemusystemx86.pp
sudo setsebool -P domain_can_mmap_files 1
else
echo "  /dev/shm/looking-glass rw," >> /etc/apparmor.d/abstractions/libvirt-qemu 
fi
