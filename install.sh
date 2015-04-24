#!/bin/sh

set -euf
# no pipefail :(

# Depending on your networking configuration, you may need to specify
# a smaller MTU in order for fetch to read the necessary data from
# http://169.254.169.254/openstack/latest/meta_data.json.
# Under Neutron+GRE, the following should work
MTU="1454"

# These files will be created or edited.
LOADER_CONF="/etc/loader.conf"
FSTAB="/etc/fstab"
RC_CONF="/etc/rc.conf"
SYSLOG_CONF="/etc/syslog.conf"

check_root() {
    if [ "$(id -u)" != "0" ]; then
        echo "Must be run as root" 1>&2
        exit 1
    fi
}


are_you_sure() {
    echo "This script will configure a fresh FreeBSD install to run"
    echo "appropriately within OpenStack (with KVM). It will install"
    echo "sudo and some init scripts, amend important configuration"
    echo "files (including /etc/rc.conf), lock the root account,"
    echo "and remove files from root's homedir."
    echo
    read -r -p "Are you sure you want to proceed? [y/n] " response
    echo
    if [ ! "${response}" == "y" ]; then
      exit 1
    fi
}


install_pkg() {
    echo "Checking for pkg... "
    /usr/sbin/pkg -N > /dev/null 2>&1 || \
    echo "pkg not found, bootstrapping..." && \
    /usr/bin/env ASSUME_ALWAYS_YES=YES /usr/sbin/pkg bootstrap
}


install_sudo() {
    echo "Installing sudo from packages."
    /usr/sbin/pkg install -y sudo
    echo "done."
}


install_openstack_init() {
  local rc_path="/usr/local/etc/rc.d/"
  local download_url="https://raw.githubusercontent.com/shartzel/freebsd_openstack_init/master/rc_scripts/"

  if [ ! -d "${rc_path}" ]; then
    /bin/mkdir -p "${rc_path}"
  fi

  echo -n "Downloading OpenStack rc files from ${download_url}... "

  for file in os.subr os_firstboot os_growroot os_hostname os_injectkey os_userdata; do
    file_path="${rc_path}""${file}"
    download_path="${download_url}""${file}"

    if [ ! -e "${file_path}" ]; then
      /usr/bin/fetch -q --no-verify-peer "${download_path}" -o "${file_path}"
      chmod 755 "${file_path}"
    else
      echo "${file_path} exists, skipping"
    fi

  done
  echo "done."
}


fix_loader_conf() {
    echo -n "Updating $LOADER_CONF... "
    if [ -f "$LOADER_CONF" ]; then
        echo -n "$LOADER_CONF unexpectedly exists. Appending values... "
    fi
    echo console=\"comconsole,vidconsole\" >> "$LOADER_CONF"
    echo autoboot_delay=\"1\" >> "$LOADER_CONF"
    echo "done."
}


fix_etc_fstab() {
    echo -n "Updating $FSTAB... "
    FSTAB_TMP=$(mktemp /tmp/fstab.XXXXXXXXXX)
    sed -e 's/ada/vtbd/g' "$FSTAB" >> "$FSTAB_TMP"
    mv "$FSTAB_TMP" "$FSTAB"
    echo "done."
}


fix_etc_rcconf() {
    echo -n "Updating $RC_CONF... "
    RC_CONF_TMP=$(mktemp /tmp/rcconf.XXXXXXXXXX)
    # delete existing lines re: ifconfig
    sed -e '/^ifconfig/d' "$RC_CONF" >> "$RC_CONF_TMP"
    # append more appropriate lines
    echo ifconfig_vtnet0_name=\"em0\" >> "$RC_CONF_TMP"
    echo ifconfig_em0=\"DHCP mtu $MTU\" >> "$RC_CONF_TMP"
    echo os_growroot_enable=\"YES\" >> "$RC_CONF_TMP"
    echo os_injectkey_enable=\"YES\" >> "$RC_CONF_TMP"
    echo os_injectkey_user=\"openstack\" >> "$RC_CONF_TMP"
    echo os_hostname_enable=\"YES\" >> "$RC_CONF_TMP"
    echo os_firstboot_enable=\"YES\" >> "$RC_CONF_TMP"
    echo os_userdata_enable=\"YES\" >> "$RC_CONF_TMP"
    mv "$RC_CONF_TMP" "$RC_CONF"
    echo "done."
}


fix_console_logs() {
    echo -n "Updating $SYSLOG_CONF... "
    touch /var/log/console.log
    chmod 600 /var/log/console.log
    SYSLOG_CONF_TMP=$(mktemp /tmp/syslogconf.XXXXXXXXXX)
    sed -e 's/^\#console.info/console.info/' "$SYSLOG_CONF" >> "$SYSLOG_CONF_TMP"
    mv "$SYSLOG_CONF_TMP" "$SYSLOG_CONF"
    echo "done."
}


clean_up() {
    echo "Cleaning up files in /root/... "
    for file in `ls -I /root/`; do rm -ri $file; done
    echo "Zeroing unused space... "
    dd if=/dev/zero of=/zerofile bs=1M || sync && rm /zerofile
    echo "Locking root account... "
    pw lock root
    echo "Clearing root history... "
    set history = 0
    echo -n "Shutting down in 10 seconds... "
    for sec in 10 9 8 7 6 5 4 3 2 1; do echo -n "$sec... " && sleep 1; done
    echo
    shutdown -h now
}


main() {
  check_root
  are_you_sure
  install_pkg
  install_sudo
  install_openstack_init
  fix_loader_conf
  fix_etc_fstab
  fix_etc_rcconf
  fix_console_logs
  clean_up
}

main
