#!/bin/sh

echo "Downloading ubuntu ISO image: ubuntu-16.04.3-server-amd64.iso..."
if [ ! -f /images/ubuntu-16.04.3-server-amd64.iso ]; then
    wget http://releases.ubuntu.com/16.04.3/ubuntu-16.04.3-server-amd64.iso \
    -O /images/ubuntu-16.04.3-server-amd64.iso
fi
echo "Done!"

echo "Clean old files..."
rm -rf dappnode-iso
rm DappNode-ubuntu-*

echo "Extracting the iso..."
xorriso -osirrox on -indev /images/ubuntu-16.04.3-server-amd64.iso \
 -extract / dappnode-iso

echo "Obtaining the isohdpfx.bin for hybrid ISO..."
dd if=/images/ubuntu-16.04.3-server-amd64.iso bs=512 count=1 \
of=dappnode-iso/isolinux/isohdpfx.bin

cd dappnode-iso

echo "Creating necessary directories and copying files"
mkdir dappnode
cp -r ../dappnode/* dappnode/

echo "Appending the Ubuntu Server minimal preseed files with DappNode"
echo "d-i preseed/late_command string \
in-target mkdir -p /opt/dappnode ; \
cp -ar /cdrom/dappnode/* /target/opt/dappnode/ ; \
cp -a /cdrom/dappnode/scripts/rc.local /target/etc/rc.local ;\
cp -a /cdrom/dappnode/bin/docker/docker-compose-Linux-x86_64 /target/usr/local/bin/docker-compose ; \
in-target chmod +x /opt/dappnode/scripts/dappnode_install_pre.sh ; \
in-target chmod +x /opt/dappnode/scripts/load_docker_images.sh ; \
in-target chmod +x /usr/local/bin/docker-compose ; \
in-target /opt/dappnode/scripts/dappnode_install_pre.sh" | tee -a preseed/hwe-ubuntu-server.seed

echo "Appending the Ubuntu Server preseed files with DappNode" 
echo "d-i preseed/late_command string \
in-target mkdir -p /opt/dappnode ; \
cp -ar /cdrom/dappnode/* /target/opt/dappnode/ ; \
cp -a /cdrom/dappnode/scripts/rc.local /target/etc/rc.local ;\
cp -a /cdrom/dappnode/bin/docker/docker-compose-Linux-x86_64 /target/usr/local/bin/docker-compose ; \
in-target chmod +x /opt/dappnode/scripts/dappnode_install_pre.sh; \
in-target chmod +x /opt/dappnode/scripts/load_docker_images.sh ; \
in-target chmod +x /usr/local/bin/docker-compose ; \
in-target /opt/dappnode/scripts/dappnode_install_pre.sh" | tee -a preseed/ubuntu-server.seed

echo "Configuring the Ubuntu boot menu for DappNode"
rm -f boot/grub/grub.cfg
cp ../boot/grub.cfg boot/grub/grub.cfg
cd isolinux
cpio -id init < bootlogo
cat bootlogo | cpio -t > /tmp/list
cp ../../boot/txt.cfg txt.cfg
cp ../../boot/splash.pcx splash.pcx
cpio -o < /tmp/list > bootlogo
cd ..

echo "Generating new iso..."
xorriso -as mkisofs -isohybrid-mbr isolinux/isohdpfx.bin \
-c isolinux/boot.cat -b isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 \
-boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot \
-isohybrid-gpt-basdat -o /images/DAppNode-ubuntu-16.04.3-server-amd64.iso .
