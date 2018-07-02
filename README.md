**Table of Contents**

- [Headless MetaTrader 4 Terminal in wine](#headless-metatrader-4-terminal-in-wine)
  - [Configure the host system](#configure-the-host-system)
  - [Prepare distribution with MetaTrader 4](#prepare-distribution-with-metatrader-4)
  - [Run the container](#run-the-container)
  - [Monitor the terminal](#monitor-the-terminal)
    - [Screenshots](#screenshots)
    - [VNC server](#vnc-server)
    - [X Window System of the host](#x-window-system-of-the-host)
  - [Extending the image](#extending-the-image)
  - [Known issues](#known-issues)
  - [Troubleshooting](#troubleshooting)

# Headless MetaTrader 4 Terminal in wine

This image is a prepared environment to execute a MetaTrader 4 Terminal which you drop to the container. Most likely, this will be enough to run any EA/script but you should test this by yourself.

The image has all dependencies which required to run Myfxbook EA.

## Configure the host system

The cheapest $5/mon DigitalOcean droplet is enough for running the container. If you haven't a DigitalOcean account you can register by my referral [link](https://m.do.co/c/8a6e11b01bba) to get $10 credit.

A user in the image who runs MetaTrader app has UID 1000 (you can change it by `--build-arg USER_ID=NNNN` of `docker build`), so you may need to create a user in the host OS to map with it. Let's name it "monitor" for example. The user should be in docker group to run the container.

```bash
useradd -u 1000 -s /bin/bash -mU monitor
adduser monitor docker
```

## Prepare distribution with MetaTrader 4

1. Install appropriate (branded) MT4 terminal locally (yep, you can do it on Windows) and close it if opened after installation.
1. Run the terminal with [`/portable`](https://www.metatrader4.com/en/trading-platform/help/userguide/start_comm) parameter to create a structure of Data directory inside the directory with the terminal. I recommend you to use `cmd.exe` program to do this. And if the terminal was installed to C: drive you may be required to start cmd.exe with administrative privileges to have access to create files in the terminal dir.
1. In the terminal close the connection dialog and all opened charts to prevent connecting to any server and opening any chart at the terminal startup.
1. Open the terminal settings and:
  * remove checks from Saving login/password and News options
  * reduce max amount of bars on the chart and in the history to 5000 if your program accept this
  * enable One-click trading
  * enable the ability to auto-trading and using DLLs if your program required for
  * disable Audio events because no one will hear them
1. Connect to a server by any login to initialize history and other directories on the disk
1. Close the terminal.
1. Delete all temporary and unrequired files from the directory with the terminal (`terminal.ico`, `uninstall.exe`, `Sounds` dir, log files, etc).
1. If you required for Myfxbook EA then [install the EA](https://www.myfxbook.com/help/connect-metatrader-ea).
1. Edit a file `startup-example.ini` (only Login, Password, Server, Symbol fields usually) and save it in the root of the directory of the terminal by name `startup.ini`. If you don't use Myfxbook EA then change field Expert too.
1. If you use Myfxbook EA then edit a file `Preset-example.set` and save it in directory `MQL4/Presets/` of the terminal by the name `Preset.set`.

## Run the container

Login by user "monitor" and type:

```bash
docker run -d --rm \
    --cap-add=SYS_PTRACE \
    -v /path/to/prepared/mt4/distro:/home/winer/.wine/drive_c/mt4 \
    nevmerzhitsky/headless-metatrader4
```

Or do it by root but add `--user 1000` parameter to command.

Without `--cap-add=SYS_PTRACE` parameter you will can't attach any EA to chart and run any script. (I think this is due to checking for any debugger attached to the terminal - protection from sniffing by MetaQuotes.) If your EA/script doesn't work even with `--cap-add=SYS_PTRACE` then replace it with `--privileged` parameter and try again. But this decrease security thus do it at your own risk! Instead of this, you can investigate which `--cap-add` values will fix you EA/script.

You can use `-it` parameters instead of `-d` to move the main process to the foreground. Worth noting, the main process of the container (script `run_mt.sh`) will not catch `Ctrl+C` properly as it does for SIGTERM from `docker stop`. This may lead to abnormal termination of the terminal.

A base image is Ubuntu, therefore if you want to debug the container then add `--entry-point bash` parameter to the `docker run` command.

## Monitor the terminal

If you need to check visually what your MetaTrader terminal doing, you have several options.

### Screenshots

The first option is a built-in script which takes a screenshot of the Xvfb screen. Add `-v /path/to/screenshots/dir:/tmp/screenshots` parameter to `docker run` command then run this command: `docker exec <CONTAINER_ID> /docker/screenshot.sh`. By default, the name of the screenshot is current time in the container, but you can override it by the first argument of screenshot.sh: `docker exec <CONTAINER_ID> /docker/screenshot.sh my-screenshot`.

### VNC server

The second option is setup VNC server in the container and connect to the container via VNC client. This gives you the ability to manipulate the terminal as a usual desktop app. For example, you can install `x11vnc` by `apt-get`. So an example of running the stack is:

```bash
Xvfb $DISPLAY -screen $SCREEN_NUM $SCREEN_WHD \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    &> /tmp/xvfb.log &
sleep 2
x11vnc -bg -nopw -rfbport 5900 -forever -xkb -o /tmp/x11vnc.log
sleep 2
wine terminal /portable startup.ini &
```

You can use `run_mt.sh` as skeleton to add this step.

You should publish 5100 port by adding `-p 5900:5900` parameter to `docker run`. Note that anybody can connect to 5900 port because x11vnc configured without a password. Google to understand how to protect and secure your VNC connection.

### X Window System of the host

The third option is use X Window System of the host.

To use the display :1 of the host from the container just add these parameters to `docker run`:
* `-e DISPLAY=:1`
* `-v /tmp/.X11-unix:/tmp/.X11-unix:ro`

You may need to give access to the display on the host by the command `DISPLAY=:1 xhost +localhost` (read man of xhost for details).

After this, if the host is your own machine you will be able to control the terminal as a usual desktop app.

But if the host is a hosted server you should be done additional work before running `docker run`. Logic is the same as the second option, but you will install VNC server to the host instead of the container. For example, you can use Xfce and TightVNC for this. Read [an article](https://medium.com/google-cloud/linux-gui-on-the-google-cloud-platform-800719ab27c5) to setup the stack. And google to understand how to protect and secure your VNC connection. Then run `docker run` with the additional parameters.

## Extending the image

You can make your own `Dockerfile` inherited from this image and copy a particular distribution of MetaTrader 4 Terminal to an image on build phase. For this task, env variables `$USER` and `$MT4DIR` are acceptable.

You can make an archive with the content from section "Prepare distribution with MetaTrader 4" by an appropriate tool. E.g. `cd mt4-distro; tar cfj ../mt4.tar.bz2 *`. Make sure that no root directory exists in the archive. Then you can extract the archive into the image by instruction `ADD mt4.tar.bz2 $MT4DIR`.

## Known issues

If the view area of Xvfb is lesser than the screen resolution (1366x768 by default) you can fix it by starting the terminal with a desktop manager: fluxbox, openbox or the same. Both packages available by `apt-get` and can be started just by `fluxbox &` or `openbox &`. So an example of running the stack is:

```bash
Xvfb $DISPLAY -screen $SCREEN_NUM $SCREEN_WHD \
    +extension GLX \
    +extension RANDR \
    +extension RENDER \
    &> /tmp/xvfb.log &
sleep 2
fluxbox &
sleep 2
wine terminal /portable startup.ini &
```

You can use `run_mt.sh` as skeleton to add this step.

If you using local VNC server also then you should run it right after the desktop manager.

## Troubleshooting

If you see this error in the container logs:

```
X Error of failed request:  BadAccess (attempt to access private resource denied)
  Major opcode of failed request:  129 (MIT-SHM)
  Minor opcode of failed request:  3 (X_ShmPutImage)
  Serial number of failed request:  458
  Current serial number in output stream:  458
```

Then try to add `--ipc=host` parameter to the `docker run` command due to [a comment](https://github.com/osrf/docker_images/issues/21#issuecomment-239334515). But this decrease security thus do it at your own risk!
