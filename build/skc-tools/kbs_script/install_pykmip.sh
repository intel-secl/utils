#!/bin/bash
HOME_DIR=$(pwd)

# Check OS
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"

if [[ $EUID -ne 0 ]]; then 
	echo "This installer must be run as root"
	exit 1
fi

echo "Installing PYKMIP SERVER..."

COMPONENT_NAME=pykmip
SERVICE_USERNAME=pykmip
PRODUCT_HOME=/opt/$COMPONENT_NAME
PYKMIP_PATH=/etc/$SERVICE_USERNAME
POLICIES_PATH=$PYKMIP_PATH/policies
LOG_PATH=/var/log/$COMPONENT_NAME

if [ "$OS" == "rhel" ]; then
	dnf -qy install python3-pip vim-common || exit 1
	ln -s /usr/bin/python3 /usr/bin/python  > /dev/null 2>&1
	ln -s /usr/bin/pip3 /usr/bin/pip  > /dev/null 2>&1 
	pip3 install pykmip==0.9.1 || exit 1
elif [ "$OS" == "ubuntu" ]; then
	apt -y install python3-pip vim-common || exit 1
	ln -s /usr/bin/python3 /usr/bin/python  > /dev/null 2>&1
	ln -s /usr/bin/pip3 /usr/bin/pip  > /dev/null 2>&1
	pip3 install pykmip==0.9.1 || exit 1
fi

pykmip_cleanup() {
	echo "Stop pykmip service"
	systemctl disable $COMPONENT_NAME.service > /dev/null 2>&1
	systemctl stop $COMPONENT_NAME.service > /dev/null 2>&1
	echo "Kill pykmip process"
	ps -ef | grep run_server.py | grep -v grep | awk '{print $2}' | xargs kill > /dev/null 2>&1
	echo "Remove pykmip files"
	rm -rf $PRODUCT_HOME $PYKMIP_PATH $LOG_PATH
}

pykmip_cleanup

echo "Setting up PYKMIP Linux User..."
id -u $SERVICE_USERNAME 2> /dev/null || useradd --comment "PYKMIP SERVER" --home $PRODUCT_HOME --shell /bin/false $SERVICE_USERNAME

# Create logging dir in /var/log
mkdir -p $LOG_PATH 
if [ $? -ne 0 ]; then
	echo "${red} Cannot create directory: $LOG_PATH"
	exit 1
fi
chown $SERVICE_USERNAME:$SERVICE_USERNAME $LOG_PATH && chmod 755 $LOG_PATH

# Create pykmip and policies directory
mkdir -p $POLICIES_PATH 
if [ $? -ne 0 ]; then
	echo "${red} Cannot create directory: $POLICIES_PATH"
	exit 1
fi
chown $SERVICE_USERNAME:$SERVICE_USERNAME $POLICIES_PATH && chmod 755 $POLICIES_PATH
chown $SERVICE_USERNAME:$SERVICE_USERNAME $PYKMIP_PATH && chmod 755 $PYKMIP_PATH

# Create Product Home directory
mkdir -p $PRODUCT_HOME
if [ $? -ne 0 ]; then
	echo "${red} Cannot create directory: $PRODUCT_HOME"
	exit 1
fi
chmod 755 $PRODUCT_HOME

# Copy scipts/config files to pykmip directory
cp -pf ./create_certificates.py $PYKMIP_PATH 
cp -pf ./run_server.py $PYKMIP_PATH
cp -pf ./server.conf $PYKMIP_PATH

# Run certificate script to generate certificates
cd $PYKMIP_PATH
python3 create_certificates.py $KBS_KMIP_IP
if [ $? -ne 0 ]; then
	echo "${red} Create Certificates failed"
	exit 1
fi
chown $SERVICE_USERNAME:$SERVICE_USERNAME $PYKMIP_PATH/* && chmod 644 $PYKMIP_PATH/*

cd $HOME_DIR 

# Install systemd script
cp ./$SERVICE_USERNAME.service $PRODUCT_HOME && chown $SERVICE_USERNAME:$SERVICE_USERNAME $PRODUCT_HOME/$SERVICE_USERNAME.service && chown $SERVICE_USERNAME:$SERVICE_USERNAME $PRODUCT_HOME

# Enable systemd service
systemctl enable $PRODUCT_HOME/$COMPONENT_NAME.service
systemctl daemon-reload

systemctl start $COMPONENT_NAME
echo "Waiting for daemon to settle down before checking status"

sleep 3

systemctl status $COMPONENT_NAME 2>&1 > /dev/null
if [ $? != 0 ]; then
	echo "Installation completed with Errors - $COMPONENT_NAME daemon not started."
	echo "Please check errors in syslog using \`journalctl -u $COMPONENT_NAME\`"
	exit 1
fi
echo "$COMPONENT_NAME daemon is running"
echo "Installation completed successfully!"
