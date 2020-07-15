#!/bin/bash

ip=$(hostname --ip)
export ROS_IP=$ip
export ROS_MASTER_URI="http://$ip:11311"
export GAZEBO_MASTER_URI="http://$ip:11345"

DISPLAY_NUM=0
unset TEST_HAS_RUN
until [ $TEST_HAS_RUN ] || (( $DISPLAY_NUM > 30 ))
do
 Xvfb :$DISPLAY_NUM &
 sleep 2  # assumption here is that Xvfb will exit quickly if it can't launch
 COUNT=$(ps -ef |grep Xvfb |grep -v "grep" |wc -l)
echo $COUNT
if [ $COUNT -eq 0 ]; then
    let DISPLAY_NUM=$DISPLAY_NUM+1
else
    echo "launching test on :$DISPLAY_NUM"
    TEST_HAS_RUN=1
    pkill Xvfb*
fi
done
echo "export DISPLAY=:${DISPLAY_NUM}" >> /root/.bashrc

# Start XVnc/X/Lubuntu
chmod -f 777 /tmp/.X11-unix
# From: https://superuser.com/questions/806637/xauth-not-creating-xauthority-file (squashes complaints about .Xauthority)
touch ~/.Xauthority
xauth generate :0 . trusted
#/opt/TurboVNC/bin/vncserver -depth 24 -geometry 1680x1050
$HOME = /root
echo $VNC_PASSWD | vncpasswd -f > $HOME/.vnc/passwd
chmod 0700 $HOME/.vnc
chmod 0600 $HOME/.vnc/passwd
chown `stat --printf=%u:%g $HOME` -R $HOME/.vnc

# Without password
vglrun /opt/TurboVNC/bin/vncserver -geometry 1920x1080 -geometry 1024x768 -depth 24 -dpi 96 -nolisten tcp -bs -ac -rfbport $PAI_CONTAINER_HOST_vnc_PORT_LIST

/opt/noVNC/utils/launch.sh --listen $PAI_CONTAINER_HOST_vnc_http_PORT_LIST --vnc localhost:$PAI_CONTAINER_HOST_vnc_PORT_LIST  >> vnc.log &


