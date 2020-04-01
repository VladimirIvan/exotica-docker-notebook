#!/bin/bash
# Copyright (c) Jupyter Development Team.
# Distributed under the terms of the Modified BSD License.
IP=`ifconfig eth0 | grep 'inet' -m 1 | cut -d: -f1 | awk '{print $2}'`
echo Jupyter notbook URL: http://$IP:8888

set -e

source ~/catkin_ws/install/setup.bash

roscore &

meshcat-server -z=tcp://127.0.0.1:6000 &
meshcat-ros-fileserver -f / &

cmd=(jupyter notebook "$@" --ip=0.0.0.0 --no-browser)

echo "Executing the command: ${cmd[@]}"
exec "${cmd[@]}"
