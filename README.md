freebsd_openstack_init
======================

Bare-bones cloud-init workalike for FreeBSD that requires very little outside
of the base install.

How to Prepare FreeBSD for Life Inside OpenStack
------------------------------------------------

1. Start by installing FreeBSD into KVM on Linux, or VirtualBox. As part of
the install, skip distribution content that you don't need in the most basic
FreeBSD image (EG games, lib32, ports). Configure the network interface for
IPv4 and DHCP. It's easiest to use the 'Guided' option for partitioning; make
sure to delete the swap partition. SSHD needs to be enabled at boot.

2. Boot into your fresh FreeBSD VM.

3. Fetch and run install.sh as root. It will do a number of things:

  * Bootstrap ``pkg`` in order to install ``sudo``
  * Download and install the RC scripts from this repo, and configure them
    to run at boot
  * Adjust ``/etc/fstab``, ``/etc/loader.conf``, ``/etc/syslog.conf``
  * Do some cleanup, including locking the root account

4. Optionally, use ``qemu-img convert`` to convert or compress your
   VM disk image to QCOW2

5. Upload image to glance


What the RC Scripts Do
----------------------

Most of the [image requirements](http://docs.openstack.org/image-guide/content/ch_openstack_images.html).

* Grows the root partition to the size specified by the flavor
* Sets up a user ('openstack', by default)with access via a public key from
  metadata
* Makes sure that user has sudo access, since the root user is locked
* Writes boot log to console


What the RC Scripts Don't Do Yet
--------------------------------

* Process complex user-data. A simple shell script will work fine.

Notes
-----

If you need a more fully-featured cloud-init, and don't mind having to install
python to get it running, you should take a look at [bsd-cloudinit](http://pellaeon.github.io/bsd-cloudinit/).
