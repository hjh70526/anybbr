#!/bin/bash
image='https://github.com/wuntel/anybbr/raw/cloud-image/centos-7.7-x86_64-docker.tar.xz'
bbx='https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-x86_64'
nc_root='/centos7'
download(){
if command -v wget >/dev/null 2>&1 ;then
	mkdir $nc_root
	wget -O "$nc_root/centos7.tar.xz" $image
	wget -O "$nc_root/busybox" $bbx
	chmod 777 "$nc_root/busybox"
	else echo "ERROR:请安装wget";exit
fi
}
del_all(){
	cp /etc/fstab $nc_root
	if command -v chattr >/dev/null 2>&1; then
		find / -type f \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path "$nc_root/*" \) \
			-exec chattr -i {} + 2>/dev/null || true
	fi
	find / \( ! -path '/dev/*' -and ! -path '/proc/*' -and ! -path '/sys/*' -and ! -path "$nc_root/*" \) -delete 2>/dev/null || true
}
extract_image(){
	xzcat="$nc_root/busybox xzcat"
	tar="$nc_root/busybox tar"
	$xzcat "$nc_root/centos7.tar.xz" | $tar -x -C /
	mv $nc_root/fstab /etc 
}
install_package(){
	echo "nameserver 8.8.8.8" > /etc/resolv.conf
	yum install rpm-build grub2 dhclient openssh-server passwd kernel -y || true
	sed -i '/^#PermitRootLogin\s/s/.*/&\nPermitRootLogin yes/' /etc/ssh/sshd_config
	systemctl enable sshd
	read -p "请修改root密码:" password
	echo $password | passwd --stdin root
}
install_grub_netcfg(){
	device=$(lsblk -npsro TYPE,NAME  | awk '($1 == "disk") { print $2}' | head -n1)
	grub2-install $device
	echo -e "GRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX=\"net.ifnames=0\"" > /etc/default/grub
	grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null
	touch /etc/sysconfig/network
	cat<<eof>/etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
eof
}
download
del_all
extract_image
install_package
install_grub_netcfg
rm -rf $nc_root
yum clean all
echo -e "\n please run \"sync;reboot -f\" \n"
