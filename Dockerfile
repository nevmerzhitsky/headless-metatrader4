FROM ubuntu:16.04
LABEL maintainer="sergey.nevmerzhitsky@gmail.com"

WORKDIR /tmp/

RUN set -ex; \
    dpkg --add-architecture i386; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        apt-transport-https \
        binutils \
        cabextract \
        curl \
        p7zip \
        software-properties-common \
        wget \
        unzip \
        xz-utils \
        xvfb

RUN set -ex; \
    wget https://dl.winehq.org/wine-builds/Release.key; \
    apt-key add Release.key; \
    apt-add-repository https://dl.winehq.org/wine-builds/ubuntu/; \
    DEBIAN_FRONTEND=noninteractive apt-get update -y; \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --install-recommends \
        winehq-stable; \
    rm Release.key

RUN set -ex; \
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks; \
    chmod +x winetricks; \
    mv winetricks /usr/local/bin

ARG USER=winer
ARG HOME=/home/$USER
# To access the values from children containers.
ENV USER=$USER \
    HOME=$HOME

RUN set -ex; \
    groupadd $USER;\
    useradd -d $HOME -g $USER -ms /bin/bash $USER

USER $USER
WORKDIR $HOME

ENV WINEARCH=win32
ENV WINEPREFIX=$HOME/.wine
ENV MT4DIR=$WINEPREFIX/drive_c/mt4

# @TODO Install actual versions of Mono and Gecko dynamically
ADD cache $HOME/.cache
USER root
RUN chown $USER:$USER -R $HOME/.cache
USER $USER

USER root
COPY waitonprocess.sh /docker/
RUN chmod a+rx /docker/waitonprocess.sh

USER $USER
RUN set -ex; \
    wine wineboot --init; \
    /docker/waitonprocess.sh wineserver
RUN set -ex; \
    winetricks --unattended dotnet40; \
    winetricks --unattended dotnet_verifier; \
    /docker/waitonprocess.sh wineserver

WORKDIR $MT4DIR

ENTRYPOINT ["wine", "terminal", "/portable", "myfxbook_ea.ini"]
