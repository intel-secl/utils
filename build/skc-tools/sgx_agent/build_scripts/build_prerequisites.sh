#!/bin//bash
GO_VERSION=go1.14.2

# Check OS and VERSION
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"
VER=$(cat /etc/os-release | grep ^VERSION_ID | tr -d 'VERSION_ID="')
OS_FLAVOUR="$OS""$VER"

install_go()
{
	go version > /dev/null 2>&1
	if [ $? -ne 0 ]; then
		echo "golang not installed. installing now"
		wget -q --delete-after https://dl.google.com/go/$GO_VERSION.linux-amd64.tar.gz -O - | tar -xz || exit 1
		mv -f go /usr/local
		grep -q '/usr/local/go/bin' ~/.bash_profile || echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bash_profile
		[[ "$PATH" == *"/usr/local/go/bin"* ]] || PATH="${PATH}:/usr/local/go/bin"
	fi
}

install_pre_requisites()
{
	if [ "$OS" == "rhel" ]; then
		dnf install -y wget tar git gcc-c++ make curl-devel
		dnf install -y https://dl.fedoraproject.org/pub/fedora/linux/releases/32/Everything/x86_64/os/Packages/m/makeself-2.4.0-5.fc32.noarch.rpm
	elif [ "$OS" == "ubuntu" ]; then
		apt install -y wget tar build-essential libcurl4-openssl-dev makeself
	fi
}

install_pre_requisites
install_go
