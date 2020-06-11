FROM ros:melodic-ros-core

ARG NB_USER="exotica"
ARG NB_UID="1000"
ARG NB_GID="100"

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
   apt-get install -yq --no-install-recommends \
   wget bzip2 ca-certificates sudo locales fonts-liberation \
   python-catkin-tools ros-melodic-talos-description \
   ros-melodic-exotica-val-description \
   python-pip python3-pip net-tools libzmq3-dev python3-setuptools python-setuptools && \
   pip3 install wheel && \
   pip2 install wheel && \
   pip3 install jupyter ipywidgets tini && \
   pip2 install numpy==1.16.0 scipy matplotlib ipykernel ipywidgets meshcat && \
   rm -rf /var/lib/apt/lists/* && \
   echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
   locale-gen && \
   sed -i 's/^#force_color_prompt=yes/force_color_prompt=yes/' /etc/skel/.bashrc

# Configure environment
ENV SHELL=/bin/bash \
    NB_USER=$NB_USER \
    NB_UID=$NB_UID \
    NB_GID=$NB_GID \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US.UTF-8
ENV HOME=/home/$NB_USER

# Add a script that we will use to correct permissions after running certain commands
ADD scripts/fix-permissions /usr/local/bin/fix-permissions


# Create NB_USER with name exotica user with UID=1000 and in the 'users' group
# and make sure these dirs are writable by the `users` group.
RUN echo "auth requisite pam_deny.so" >> /etc/pam.d/su && \
    sed -i.bak -e 's/^%admin/#%admin/' /etc/sudoers && \
    sed -i.bak -e 's/^%sudo/#%sudo/' /etc/sudoers && \
    useradd -m -s /bin/bash -N -u $NB_UID $NB_USER && \
    chmod g+w /etc/passwd && \
    fix-permissions /home/$NB_USER

# Install Python 3 packages
# Remove pyqt and qt pulled in for matplotlib since we're only ever going to
# use notebook-friendly backends in these images
RUN jupyter nbextension enable --py widgetsnbextension --sys-prefix && \
    fix-permissions /home/$NB_USER

USER $NB_UID

# Import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME /home/$NB_USER/.cache/
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions /home/$NB_USER

USER root

RUN mkdir -p /home/$NB_USER/catkin_ws/src && cd /home/$NB_USER/catkin_ws/src && \
   git clone -n https://github.com/ipab-slmc/exotica.git && cd exotica && git checkout b5eb32e && \
   cd /home/$NB_USER/catkin_ws && \
   apt-get update && \
   rosdep update && \
   rosdep install --from-paths src --ignore-src -r -y -i && \
   /bin/bash -c "source /opt/ros/melodic/setup.bash && cd ~/catkin_ws && catkin init && catkin config --install -i /opt/ros/melodic --cmake-args -DCMAKE_BUILD_TYPE=Release && catkin build" && \
   echo 'source /opt/ros/melodic/setup.bash' >> /home/$NB_USER/.bashrc && \
   apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && \
   rm -rf /home/$NB_USER/catkin_ws

RUN cd /home/$NB_USER/ && \
   git clone --recursive --single-branch --branch master https://github.com/rdeits/meshcat-python.git && \
   cd /home/$NB_USER/meshcat-python && python3 setup.py install && \
   rm -rf /home/$NB_USER/meshcat-python

RUN cd /home/$NB_USER/ && \
   git clone https://github.com/VladimirIvan/meshcat_ros_fileserver.git && \
   cd /home/$NB_USER/meshcat_ros_fileserver && python3 setup.py install && \
   rm -rf /home/$NB_USER/meshcat_ros_fileserver

RUN fix-permissions /home/$NB_USER

# Configure container startup
USER $NB_UID
RUN mkdir /home/$NB_USER/notebooks
USER root

WORKDIR /home/$NB_USER/notebooks
COPY scripts/start-jupyter.sh /usr/local/bin/
ENTRYPOINT ["start-jupyter.sh", "--NotebookApp.token=''", "--NotebookApp.password=''"]

EXPOSE 8888
EXPOSE 6000
EXPOSE 7000

# Switch back to exotica to avoid accidental container runs as root
USER $NB_UID
