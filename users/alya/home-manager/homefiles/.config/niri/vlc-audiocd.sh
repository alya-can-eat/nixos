#!/bin/sh
pkill -f 'vlc cdda:///dev/sr0'
sleep 1
vlc cdda:///dev/sr0
exit
