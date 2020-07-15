FROM nvidia/cudagl:9.0-devel-ubuntu16.04
#---------------------------------------------------------------------
# Install CUDNN
#---------------------------------------------------------------------

RUN echo "deb https://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64 /" > /etc/apt/sources.list.d/nvidia-ml.list

LABEL com.nvidia.cudnn.version="7.3.1.20"

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    libcudnn7=7.3.1.20-1+cuda9.0 \
    libcudnn7-dev=7.3.1.20-1+cuda9.0 \
    && rm -rf /var/lib/apt/lists/*



ARG SOURCEFORGE=https://sourceforge.net/projects
ARG TURBOVNC_VERSION=2.1.2
ARG VIRTUALGL_VERSION=2.5.2
ARG LIBJPEG_VERSION=1.5.2
ARG WEBSOCKIFY_VERSION=0.8.0
ARG NOVNC_VERSION=1.0.0
ARG LIBARMADILLO_VERSION=6

#---------------------------------------------------------------------
# Install Linux stuff
#---------------------------------------------------------------------
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates curl wget less sudo lsof git net-tools nano psmisc xz-utils nemo vim net-tools iputils-ping traceroute htop \
    lubuntu-core chromium-browser xterm terminator zenity make cmake gcc libc6-dev \
    x11-xkb-utils xauth xfonts-base xkb-data \
    mesa-utils xvfb libgl1-mesa-dri libgl1-mesa-glx libglib2.0-0 libxext6 libsm6 libxrender1 \
    libglu1 libglu1:i386 libxv1 libxv1:i386 \
    openssh-server pwgen sudo git python python-numpy libpython-dev libsuitesparse-dev libgtest-dev \
    libeigen3-dev libsdl1.2-dev libignition-math2-dev libarmadillo-dev libarmadillo${LIBARMADILLO_VERSION} libsdl-image1.2-dev libsdl-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

#---------------------------------------------------------------------
# Install gtest
#---------------------------------------------------------------------
RUN /bin/bash -c "cd /usr/src/gtest && cmake CMakeLists.txt && make && cp *.a /usr/lib"

#---------------------------------------------------------------------
# Install VirtualGL and TurboVNC
#---------------------------------------------------------------------
RUN cd /tmp && \
    curl -fsSL -O ${SOURCEFORGE}/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_amd64.deb \
    -O ${SOURCEFORGE}/libjpeg-turbo/files/${LIBJPEG_VERSION}/libjpeg-turbo-official_${LIBJPEG_VERSION}_amd64.deb \
    -O ${SOURCEFORGE}/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_amd64.deb \
    -O ${SOURCEFORGE}/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl32_${VIRTUALGL_VERSION}_amd64.deb && \
    dpkg -i *.deb && \
    rm -f /tmp/*.deb && \
    sed -i 's/$host:/unix:/g' /opt/TurboVNC/bin/vncserver
ENV PATH ${PATH}:/opt/VirtualGL/bin:/opt/TurboVNC/bin

#---------------------------------------------------------------------
# Install noVNC
#---------------------------------------------------------------------
RUN curl -fsSL https://github.com/novnc/noVNC/archive/v${NOVNC_VERSION}.tar.gz | tar -xzf - -C /opt && \
    curl -fsSL https://github.com/novnc/websockify/archive/v${WEBSOCKIFY_VERSION}.tar.gz | tar -xzf - -C /opt && \
    mv /opt/noVNC-${NOVNC_VERSION} /opt/noVNC && \
    chmod -R a+w /opt/noVNC && \
    mv /opt/websockify-${WEBSOCKIFY_VERSION} /opt/websockify && \
    cd /opt/websockify && make && \
    cd /opt/noVNC/utils && \
    ln -s /opt/websockify

COPY requirements/xorg.conf /etc/X11/xorg.conf
COPY requirements/index.html /opt/noVNC/index.html

# Expose whatever port NoVNC will serve from. In our case it will be 40001, see ./start_desktop.sh
# EXPOSE 40001
# ENV DISPLAY :1

#---------------------------------------------------------------------
# Install desktop files for this user
#---------------------------------------------------------------------
RUN mkdir -p /root/Desktop
COPY ./requirements/terminator.desktop /root/Desktop
RUN mkdir -p /root/.config/terminator
COPY ./requirements/terminator_config /root/.config/terminator/config
COPY ./requirements/self.pem /root/self.pem

# Precede bash on all new terminator shells with vglrun so that 3d graphics apps will use the GPU
RUN perl -pi -e 's/^Exec=terminator$/Exec=terminator -e "vglrun bash"/g' /usr/share/applications/terminator.desktop

# Start setups for TurboVNC
RUN mkdir -p /root/.vnc
COPY ./requirements/xstartup.turbovnc /root/.vnc/xstartup.turbovnc
RUN chmod a+x /root/.vnc/xstartup.turbovnc

#---------------------------------------------------------------------
# Install ROS
#---------------------------------------------------------------------
RUN sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'
RUN apt-key adv --keyserver 'hkp://keyserver.ubuntu.com:80' --recv-key C1CF6E31E6BADE8868B172B4F42ED6FBAB17C654

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ros-kinetic-desktop-full \
    ros-kinetic-tf2-sensor-msgs \
    ros-kinetic-geographic-msgs \
    ros-kinetic-move-base-msgs \
    ros-kinetic-ackermann-msgs \
    ros-kinetic-unique-id \
    ros-kinetic-fake-localization \
    ros-kinetic-joy \
    ros-kinetic-imu-tools \
    ros-kinetic-robot-pose-ekf \
    ros-kinetic-grpc \
    ros-kinetic-pcl-ros \
    ros-kinetic-pcl-conversions \
    ros-kinetic-controller-manager \
    ros-kinetic-joint-state-controller \
    ros-kinetic-effort-controllers \
    && apt-get clean

# catkin build tools
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python-pyproj \
    python-catkin-tools \
    && apt-get clean

#Fix locale (UTF8) issue https://askubuntu.com/questions/162391/how-do-i-fix-my-locale-issue
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y locales
RUN locale-gen "en_US.UTF-8"

# Finish
RUN echo "source /opt/ros/kinetic/setup.bash" >> /root/.bashrc


#---------------------------------------------------------------------
# Upgrade Gazebo
#---------------------------------------------------------------------

ARG LIBSDFORMAT_VERSION=5

RUN echo "deb http://packages.osrfoundation.org/gazebo/ubuntu `lsb_release -cs` main" > /etc/apt/sources.list.d/gazebo-stable.list \
 && wget http://packages.osrfoundation.org/gazebo.key -O - | apt-key add - \
 && apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ros-kinetic-gazebo8-plugins \
    ros-kinetic-gazebo8-ros-pkgs \
    ros-kinetic-gazebo8-ros-control \
    libpcap0.8-dev \
    gazebo8-plugin-base \
    gazebo8-common \
    libsdformat${LIBSDFORMAT_VERSION}-dev \
    libgazebo8-dev \
    gazebo8 \
 && apt-get clean

RUN echo "source /usr/share/gazebo-8/setup.sh" >> /root/.bashrc


#---------------------------------------------------------------------
# Python3 packages for DNNs, RL, etc
#---------------------------------------------------------------------

# Link NCCL libray and header where the build script expects them.
RUN mkdir /usr/local/cuda-9.0/lib &&  \
    ln -s /usr/lib/x86_64-linux-gnu/libnccl.so.2 /usr/local/cuda/lib/libnccl.so.2 && \
    ln -s /usr/include/nccl.h /usr/local/cuda/include/nccl.h

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    build-essential libfreetype6-dev libzmq3-dev pkg-config \
    python3 python3-dev python3-pip python3-tk \
    swig rsync software-properties-common unzip \
    libgtk2.0-0 libgtk2.0-dev zlib1g-dev \
    tcl-dev tk-dev gfortran \
    libatlas-base-dev libatlas3-base \
    ffmpeg graphviz libxslt-dev libhdf5-dev libxml2-dev \
    libboost-program-options-dev libboost-python-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip
RUN pip3 install setuptools==39.1.0

## Install  Modules
COPY requirements/requirements.txt requirements.txt
RUN pip3 install -r requirements.txt



#---------------------------------------------------------------------
# Startup
#---------------------------------------------------------------------
COPY requirements/launch.sh /opt/noVNC/utils/launch.sh
COPY requirements/start_desktop.sh /usr/local/bin/start_desktop.sh
COPY requirements/start_desktop.sh /root/setup.sh
# Uncomment for autostart of the VNC server
#CMD /usr/local/bin/start_desktop.sh
# CMD /bin/bash
