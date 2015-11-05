# Bare-Metal Installation

# WORK IN PROGRESS, NOT WORKING YET!

This page explains how to install the INAETICS demonstrator on bare-metal machines. The hardware used for this are 6 [Intel D54250WYK NUCs](http://www.intel.com/content/www/us/en/nuc/nuc-kit-d54250wyk.html) each with 16GB of memory and a 256GB disk. On each of the NUCs, we'll install a plain CoreOS installation along with a couple of extra files to ease the bootstrap of the INAETICS demonstrator. To simplify the installation, we've created a couple of scripts that you can use to reproduce the installation on your own set of machines. These scripts can be found at Github and are used in the remainder of this document. 

## Preparations

Before we can proceed with the actual installation of CoreOS we need to do a couple of additional steps.

### Clone the installation scripts

Clone the files from this repository to a local directory.
We refer to this repository as ${BAREMETAL_INSTALL} in the remainder of this page. The repository has the following layout:

    + copy_all.sh
    + coreos-install.sh
    + download.sh
    + oem/
    |--+ default/
    |--+ nuc1/
    |--+ setup-env.sh
    + ssh/
    + ssl/
    |--+ gen_certs.sh
    `--+ openssl.cnf

### Generating a SSH key

Before we can proceed with the installation, we need a SSH public key that we can use to access each of the NUCs once CoreOS is installed. We'll be using a separate key pair for this demonstrator only which is generated by issuing:

    ~$ /usr/bin/ssh-keygen -b 2048 -C "INAETICS demonstrator" -f ./id_rsa
    Generating public/private rsa key pair.
    ...

Copy the resulting id_rsa.pub to the ${BAREMETAL_INSTALL}/ssh directory.

> If you want to access any of the NUCs later on, you can use the following command to access them:
>
>`~$ ssh -i /path/to/id_rsa core@172.17.8.20`

### Generating the SSL keys

The baremetal demonstrator uses several SSL certificates to secure Kubernetes. For this we use the gen_certs.sh script found in the ${BAREMETAL_INSTALL}/ssl directory. Running this script generates several keypairs in ${BAREMETAL_INSTALL}/ssl/out. Each of these keypairs are properly signed by another generated keypair that acts as certificate authority. After the generation is complete, the installation scripts will use the correct files automatically (they are copied to the needed locations later on).

### Preparing a bootable USB disk

The Intel NUCs are UEFI based machines, which allows us to use a nice trick to boot any ISO image, such as CoreOS, without the need to burn that image to disk (as you normally would to when creating a bootable CD or USB drive). This allows us to use the USB drive to carry our INAETICS installation files as well. Creating such a "multi-boot" USB drive is nicely documented on [this page](http://ubuntuforums.org/showthread.php?t=2276498). Finally you need to edit `/boot/grub/grub.cfg`, replace the content with

    menuentry 'CoreOS' {
	    set isofile="/coreos_production_iso_image.iso"
	    loopback loop $isofile
	    linux (loop)/coreos/vmlinuz ro noswap console=tty0 console=ttyS0 coreos.autologin=tty1 coreos.autologin=ttyS0 --
	    initrd (loop)/coreos/cpio.gz
    }

### Downloading needed binaries, docker images and CoreOS images
For running the INAETICS demonstrator, several INAETICS and 3rd party binaries and Docker images are needed. Run the `${BAREMETAL_INSTALL}/initial-download.sh` script to do this. It also downloads and verifies the CoreOS image which will be used for booting the USB drive and installing the NUCs.

Now we can copy the files from ${BAREMETAL_INSTALL} to the bootable USB drive using the `${BAREMETAL_INSTALL}/copy_all.sh`. This script needs a single argument which should be the path to your mounted USB drive. For example:

    $ ./copy_all.sh /Volumes/GRUB2EFI

## Installation

The installation is to be repeated for each NUC. We assign a hostname to each of the NUCs to make them easy identifiable when you SSH into them. For our own setup, we've used the names nuc1, nuc2, ..., nuc6.

> If you want to use your own naming convention instead, be sure to modify the directory names in ${BAREMETAL_INSTALL}/oem to reflect this!

To install CoreOS, boot from the USB drive, mount the disk and run the installer script (replace <NAME> with the name of the NUC you’re installing to, e.g. nuc1):

    $ sudo mount /dev/sdb1 /mnt && cd /mnt
    $ sudo ./coreos-install.sh -d /dev/sda -n <NAME>
    $ sudo reboot

Unplug the USB drive and watch your NUC boot into the freshly installed CoreOS image. You should be able to access it through SSH using the key you've generated previously (see above).

## Running the demonstrator

The installation contains everything which is needed for running the INAETICS demonstrator. You only need be sure that you start NUC1 first, because it is the DHCP server for the other NUCs. For more information on how to check, use and debug the demonstrator, please see the documentation on our [Kubernetes Demo Cluster repository](https://github.com/INAETICS/kubernetes-demo-cluster)

# Tips & Tricks

## Mounting the USB drive on OSX

If the USB drive is not mounted automatically, you can do that manually:

    $ diskutil list (look for the disk number of the USB drive)    
    $ mkdir /Volumes/USBdrive
    $ sudo mount -t msdos /dev/disk<DISKNUMBER>s1 /Volumes/USBDrive

## CoreOS autologin

If you want to use CoreOS directly on the NUCs (so not via ssh), you can change the boot options to let CoreOS automatically login the `core` user.

- press `cursor down` when you see the grub menu
- choose `CoreOS USR-A`
- press `e`
- add `coreos.autologin` to the boot options
- press `F10` to boot the just edited boot entry
