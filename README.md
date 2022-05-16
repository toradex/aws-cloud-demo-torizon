# Installing Pre-Requisites #

## On your Linux PC ##

**On your Linux PC**

[Download and install the AWS CLI](http://docs.aws.amazon.com/cli/latest/userguide/installing.html) . Don't forget to follow the [Pre-requisites] (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-prereqs.html) and to [configure the CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-quickstart.html)

[Install Docker](https://docs.docker.com/get-docker/). Don't forget to login the engine on your dockerhub account using the [docker login](https://docs.docker.com/engine/reference/commandline/login/) command.

Install the following pre-requisites:
``` 
$ apt install sshpass
```

## On Maivin ##

Connect Maivin to a router with internet connection using the Ethernet Cable. Connect it to the power supply. A blue light will turn on.

Scan your local network to find the board IP and MAC address. You can [use the command line](https://developer-archives.toradex.com/knowledge-base/scan-your-local-network-to-find-the-board-ip-and-mac-address) or some [GUI-based software](https://angryip.org/download/#linux).

Connect to Maivin's terminal using `ssh` with the default username `torizon`:

```
# ssh torizon@<board-ip>
```

The default password is `torizon`. The system will ask you to change this password on firt boot.

6 - Execute the script `./run.sh`

**On your board's terminal** , stop the pre-provisioned containers by sending the command:

```
# sudo systemctl disable docker-compose
```

Reset the board.

```
# sudo reboot
```

Take a note of the IP and the new password.

# Setting Up #

Modify the `project_settings.sh` file.

Set your selected `AWS_REGION`.

Set `PROJECT_NAME` with a unique project name.

Set `DOCKERHUB_LOGIN` with your dockerhub username. This will be used to push and pull containers to Maivin.

Set your `BOARD_IP` as found on the previous steps.

Set `BOARD_PWD` with the new password for Maivin as described in the previous steps.

## Install the services in the Cloud ##

After setting up the `project_settings.sh` file, **on your PC**, use `setup_cloud_service.sh` script

```
$ cd aws-cloud-demo-torizon
$ ./setup_cloud_service.sh
```

It may take about 10 minutes to conclude.

## Install the credentials in the device ##

**on your PC**, use `setup_device.sh` script

```
$ ./setup_device.sh
```

This will start Nucleos.


