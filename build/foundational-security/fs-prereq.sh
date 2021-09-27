declare -a PRE_REQ_PACKAGES_RHEL
PRE_REQ_PACKAGES_RHEL=(
  https://download-ib01.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/m/makeself-2.4.2-1.el8.noarch.rpm
  https://www.cabextract.org.uk/cabextract-1.9.1-1.i386.rpm
  wget
  gcc
  gcc-c++
  git
  patch
  zip
  unzip
  make
  tpm2-tss-2.0.0-4.el8.x86_64
  tpm2-tss-devel.x86_64
  openssl-devel
  skopeo
)

declare -a PRE_REQ_PACKAGES_UBUNTU
PRE_REQ_PACKAGES_UBUNTU=(
  wget
  git
  patch
  zip
  unzip
  make
  cabextract
  gcc-8
  g++-8
  build-essential
  skopeo
)

declare -a DEB_PACKAGES
DEB_PACKAGES=(
  http://us.archive.ubuntu.com/ubuntu/pool/main/i/init-system-helpers/init-system-helpers_1.57_all.deb
  http://archive.ubuntu.com/ubuntu/pool/main/t/tpm-udev/tpm-udev_0.4_all.deb
  http://us.archive.ubuntu.com/ubuntu/pool/main/t/tpm2-tss/libtss2-esys0_2.3.2-1_amd64.deb
  http://security.ubuntu.com/ubuntu/pool/main/libg/libgcrypt20/libgcrypt20-dev_1.8.5-5ubuntu1_amd64.deb
  http://archive.ubuntu.com/ubuntu/pool/main/t/tpm2-tss/libtss2-dev_2.3.2-1_amd64.deb
)

OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"

#install pre-reqs
install_prereqs() {
  local error_code=0
  if [ "$OS" == "rhel" ]; then
    for package in ${!PRE_REQ_PACKAGES_RHEL[@]}; do
      local package_name=${PRE_REQ_PACKAGES_RHEL[${package}]}
      dnf install -y ${package_name}
      local return_code=$?
      if [ ${return_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${return_code}
      fi
    done
  fi

  if [ "$OS" == "ubuntu" ]; then
    add-apt-repository ppa:projectatomic/ppa -y
    apt-get update -y
    for package in ${!PRE_REQ_PACKAGES_UBUNTU[@]}; do
      local package_name=${PRE_REQ_PACKAGES_UBUNTU[${package}]}
      apt install -y ${package_name}
      local return_code=$?
      if [ ${return_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${return_code}
      fi
    done
    for package in ${!DEB_PACKAGES[@]}; do
      local package_name=${DEB_PACKAGES[${package}]}
      local TEMP_DEB=tempdb
      wget -O "$TEMP_DEB" ${package_name}
      echo $TEMP_DEB
      echo ${package_name}
      dpkg -i $TEMP_DEB
      rm -f $TEMP_DEB
      local install_error_code=$?
      if [ ${install_error_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${install_error_code}
      fi
    done
  fi
  return ${error_code}
}

# functions handling i/o on command line
print_help() {
  echo "Usage: $0 [-hs]"
  echo "    -h    print help and exit"
  echo "    -s    pre-req setup for Foundational Security"
}

dispatch_works() {
  mkdir -p ~/.tmp
  if [[ $1 == *"s"* ]]; then
    install_prereqs
  fi
}

if [ $# -eq 0 ]; then
  print_help
  exit 1
fi

OPTIND=1
work_list=""
while getopts his opt; do
  case ${opt} in
  h)
    print_help
    exit 0
    ;;
  s) work_list+="s" ;;
  *)
    print_help
    exit 1
    ;;
  esac
done

# run commands
dispatch_works $work_list
