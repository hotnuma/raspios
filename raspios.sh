#!/usr/bin/bash

basedir="$(dirname -- "$(readlink -f -- "$0";)")"
builddir="$HOME/DevFiles"
currentuser="$USER"
outfile="$HOME/install.log"
dist_id=""
cpu=$(arch)

error_exit()
{
    msg="$1"
    test "$msg" != "" || msg="an error occurred"
    printf "*** $msg\nabort...\n" | tee -a "$outfile"
    exit 1
}

create_dir()
{
    test "$1" != "" || error_exit "create_dir failed"
    test ! -d "$1" || return
    echo "*** create_dir : $1"
    mkdir -p "$1"
}

sys_upgrade()
{
    echo "*** sys upgrade" | tee -a "$outfile"
    sudo apt update 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "update failed"
    sudo apt full-upgrade 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "upgrade failed"
}

build_src()
{
    local pack="$1"
    local dest="$2"
    if [[ ! -f "$dest" ]]; then
        echo "*** build ${pack}" | tee -a "$outfile"
        git clone https://github.com/hotnuma/${pack}.git 2>&1 | tee -a "$outfile"
        pushd ${pack} 1>/dev/null
        ./install.sh 2>&1 | tee -a "$outfile"
        popd 1>/dev/null
    fi
}

# tests =======================================================================

if [[ "$EUID" = 0 ]]; then
    error_exit "*** must not be run as root"
else
    # make sure to ask for password on next sudo
    sudo -k
    if ! sudo true; then
        error_exit "*** sudo failed"
    fi
fi

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    dist_id=$VERSION_CODENAME
fi

test ! -d "/boot/grub" || error_exit "not a Raspberry Pi"

model=$(tr -d '\0' </sys/firmware/devicetree/base/model)
test "$model" == "Raspberry Pi 4 Model B Rev 1.4" \
    || error_exit "wrong board model"
    
test -f "/etc/apt/sources.list.d/raspi.list" && opt_raspi=1

# start =======================================================================

echo "===============================================================================" | tee -a $outfile
echo " Debian install..." | tee -a $outfile
echo "===============================================================================" | tee -a $outfile

# cpu governor ----------------------------------------------------------------

dest="/etc/default/cpufrequtils"
if [[ ! -f $dest ]]; then
    echo "*** set governor to performance" | tee -a "$outfile"
    sudo tee "$dest" > /dev/null << 'EOF'
GOVERNOR="performance"
EOF
fi

# raspios ---------------------------------------------------------------------

#~ dest="/boot/firmware/cmdline.txt"
#~ if [[ -f $dest ]] && [[ ! -f ${dest}.bak ]]; then
    #~ echo "*** edit /boot/cmdline.txt" | tee -a "$outfile"
    #~ sudo cp "$dest" ${dest}.bak 2>&1 | tee -a "$outfile"
    #~ sudo sed -i 's/ quiet splash plymouth.ignore-serial-consoles//' "$dest"
#~ fi

dest="/boot/firmware/config.txt"
if [[ -f "$dest" ]] && [[ ! -f "${dest}.bak" ]]; then
    echo "*** edit /boot/firmware/config.txt" | tee -a "$outfile"
    sudo cp "$dest" "${dest}.bak" 2>&1 | tee -a "$outfile"
    sudo tee "$dest" > /dev/null << 'EOF'
# http://rpf.io/configtxt

dtoverlay=vc4-kms-v3d
max_framebuffers=2
arm_64bit=1
disable_overscan=1
disable_splash=1
boot_delay=0

# overclock
over_voltage=6
arm_freq=2000
gpu_freq=600

# audio
#dtparam=audio=on

# disable unneeded
dtoverlay=disable-bt
dtoverlay=disable-wifi
EOF
fi

# install base ================================================================

dest=/usr/bin/xfce4-terminal
if [[ ! -f "$dest" ]]; then
    sys_upgrade
    echo "*** install base" | tee -a "$outfile"
    APPLIST="swaybg thunar xfce4-terminal"
    sudo apt -y install $APPLIST 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "installation failed"
fi

# uninstall ===================================================================

dest=/usr/bin/plymouth
if [[ -f "$dest" ]]; then
    echo "*** uninstall softwares" | tee -a "$outfile"
    APPLIST="gvfs-backends plymouth"
    sudo apt -y purge $APPLIST 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "uninstall failed"
    sudo apt -y autoremove 2>&1 | tee -a "$outfile"
    test "$?" -eq 0 || error_exit "autoremove failed"
fi

# services --------------------------------------------------------------------

#~ if [ "$(pidof cupsd)" ]; then
    #~ echo "*** disable services" | tee -a "$outfile"
    #~ APPLIST="anacron apparmor avahi-daemon cron cups cups-browsed"
    #~ APPLIST+=" ModemManager"
    #~ sudo systemctl stop $APPLIST 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable $APPLIST 2>&1 | tee -a "$outfile"
    #~ APPLIST="anacron.timer apt-daily.timer apt-daily-upgrade.timer"
    #~ sudo systemctl stop $APPLIST 2>&1 | tee -a "$outfile"
    #~ sudo systemctl disable $APPLIST 2>&1 | tee -a "$outfile"
#~ fi

# system settings -------------------------------------------------------------

dest="/etc/xdg/labwc/rc.xml"
if [[ ! -f "${dest}.bak" ]]; then
    echo "*** install rc.xml" | tee -a "$outfile"
    sudo cp "$dest" "${dest}.bak"
    sudo cp "$basedir/labwc/rc.xml" "$dest"
    test "$?" -eq 0 || error_exit "install rc.xml failed"
fi

dest="/etc/xdg/labwc/autostart"
if [[ ! -f "${dest}.bak" ]]; then
    echo "*** install autostart" | tee -a "$outfile"
    sudo cp "$dest" "${dest}.bak"
    sudo cp "$basedir/labwc/autostart" "$dest"
    test "$?" -eq 0 || error_exit "install autostart failed"
fi

dest="$HOME/.config/user-dirs.dirs"
if [[ ! -f "${dest}.bak" ]]; then
    echo "*** user directories" | tee -a "$outfile"
    sudo cp "$dest" "${dest}.bak"
    sudo cp "$basedir/home/user-dirs.dirs" "$dest"
    test "$?" -eq 0 || error_exit "user directories failed"
fi

# build programs ==============================================================

dest="$builddir"
if [[ ! -d "$dest" ]]; then
    echo "*** create build dir" | tee -a "$outfile"
    mkdir "$builddir"
fi

pushd "$builddir" 1>/dev/null

dest="/usr/local/include/tinyc/cstring.h"
build_src "libtinyc" "$dest"
test -f "$dest" || error_exit "compilation failed"

dest="/usr/local/bin/apt-upgrade"
build_src "systools" "$dest"
test -f "$dest" || error_exit "compilation failed"

# terminate ===================================================================

popd 1>/dev/null
echo "done" | tee -a "$outfile"


