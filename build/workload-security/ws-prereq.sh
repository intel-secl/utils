# Check OS
OS=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
temp="${OS%\"}"
temp="${temp#\"}"
OS="$temp"

declare -a PRE_REQ_REPO
PRE_REQ_REPO=(
  https://download.docker.com/linux/centos/docker-ce.repo
)

declare -a RPM_PACKAGES
RPM_PACKAGES=(
  https://download-ib01.fedoraproject.org/pub/epel/8/Everything/x86_64/Packages/m/makeself-2.4.2-1.el8.noarch.rpm
)

declare -a DEB_PACKAGES
DEB_PACKAGES=(
  http://us.archive.ubuntu.com/ubuntu/pool/main/i/init-system-helpers/init-system-helpers_1.57_all.deb
  http://archive.ubuntu.com/ubuntu/pool/main/t/tpm-udev/tpm-udev_0.4_all.deb
  http://us.archive.ubuntu.com/ubuntu/pool/main/t/tpm2-tss/libtss2-esys0_2.3.2-1_amd64.deb
  http://security.ubuntu.com/ubuntu/pool/main/libg/libgcrypt20/libgcrypt20_1.8.5-5ubuntu1_amd64.deb
  http://security.ubuntu.com/ubuntu/pool/main/libg/libgcrypt20/libgcrypt20-dev_1.8.5-5ubuntu1_amd64.deb
  http://archive.ubuntu.com/ubuntu/pool/main/t/tpm2-tss/libtss2-dev_2.3.2-1_amd64.deb
)

declare -a PRE_REQ_COMMON_PACKAGES
PRE_REQ_COMMON_PACKAGES=(
  wget
  git
  patch
  zip
  unzip
  make
  cabextract
  curl
  sudo
  wget
)

declare -a PRE_REQ_PACKAGES_RHEL
PRE_REQ_PACKAGES_RHEL=(
  glib2-devel
  glibc-devel
  gcc
  gcc-c++
  openssl-devel
  tpm2-tss-2.0.0-4.el8.x86_64
  tpm2-tss-devel.x86_64
  https://www.cabextract.org.uk/cabextract-1.9.1-1.i386.rpm
)

declare -a PRE_REQ_PACKAGES_UBUNTU
PRE_REQ_PACKAGES_UBUNTU=(
  gcc-8
  g++-8
  build-essential
  libgpg-error-dev
  software-properties-common
  gnupg2
)

declare -a PRE_REQ_PACKAGES_DOCKER
PRE_REQ_PACKAGES_DOCKER=(
  containers-common
  docker-ce-20.10.8-3.el8
  docker-ce-cli-20.10.8-3.el8
)

install_prereq_repos_rhel() {
  local error_code=0
  for url in ${!PRE_REQ_REPO[@]}; do
    local repo_url=${PRE_REQ_REPO[${url}]}
    dnf config-manager --add-repo=${repo_url}
    local return_code=$?
    if [ ${return_code} -ne 0 ]; then
      echo "ERROR: could not configure [${repo_url}]"
      return ${return_code}
    fi
  done
  return ${error_code}
}

#install generic pre-reqs
install_prereqs_packages() {
  local error_code=0
  for package in ${!PRE_REQ_COMMON_PACKAGES[@]}; do
    local package_name=${PRE_REQ_COMMON_PACKAGES[${package}]}
    if [ "$OS" == "rhel" ]; then
      dnf install -y ${package_name}
    fi
    if [ "$OS" == "ubuntu" ]; then
      export DEBIAN_FRONTEND=noninteractive
      apt-get install -y ${package_name}
    fi
    local install_error_code=$?
    if [ ${install_error_code} -ne 0 ]; then
      echo "ERROR: could not install [${package_name}]"
      return ${install_error_code}
    fi
  done
  if [ "$OS" == "rhel" ]; then
    for package in ${!PRE_REQ_PACKAGES_RHEL[@]}; do
      local package_name=${PRE_REQ_PACKAGES_RHEL[${package}]}
      dnf install -y ${package_name}
      local install_error_code=$?
      if [ ${install_error_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${install_error_code}
      fi
    done
    for package in ${!RPM_PACKAGES[@]}; do
      local package_name=${RPM_PACKAGES[${package}]}
      dnf install -y ${package_name}
      local install_error_code=$?
      if [ ${install_error_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${install_error_code}
      fi
    done
  fi
  if [ "$OS" == "ubuntu" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y

    for package in ${!PRE_REQ_PACKAGES_UBUNTU[@]}; do
      local package_name=${PRE_REQ_PACKAGES_UBUNTU[${package}]}
      apt install -y ${package_name}
      local install_error_code=$?
      if [ ${install_error_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${install_error_code}
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

install_prereq_skopeo() {
  if [ "$OS" == "rhel" ]; then
    local error_code=0
    dnf -y module disable container-tools
    dnf -y install 'dnf-command(copr)'
    dnf -y copr enable rhcontainerbot/container-selinux
    curl -L -o /etc/yum.repos.d/devel:kubic:libcontainers:stable.repo https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/CentOS_8_Stream/devel:kubic:libcontainers:stable.repo
    dnf -y install skopeo
  elif [ "$OS" == "ubuntu" ]; then
    export DEBIAN_FRONTEND=noninteractive
    source /etc/os-release
    if [ "$VERSION_ID" == "18.04" -o "$VERSION_ID" == "20.04" ]; then
      echo "deb https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/ /" | sudo tee /etc/apt/sources.list.d/devel:kubic:libcontainers:stable.list
      curl -L https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable/xUbuntu_${VERSION_ID}/Release.key | sudo apt-key add -
      apt-get -y update
    fi

    apt-get -y install skopeo
  fi
}


#install docker pre-reqs
install_prereqs_packages_docker() {
  local error_code=0
  if [ "$OS" == "rhel" ]; then
    for package in ${!PRE_REQ_PACKAGES_DOCKER[@]}; do
      local package_name=${PRE_REQ_PACKAGES_DOCKER[${package}]}
      dnf install -y ${package_name}
      local install_error_code=$?
      if [ ${install_error_code} -ne 0 ]; then
        echo "ERROR: could not install [${package_name}]"
        return ${install_error_code}
      fi
    done
  fi
  if [ "$OS" == "ubuntu" ]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -y
    apt-get install -y docker-ce=5:20.10.8~3-0~ubuntu-focal docker-ce-cli=5:20.10.8~3-0~ubuntu-focal
  fi
  return ${error_code}
}

# functions handling i/o on command line
print_help() {
  echo "Usage: $0 [-hdcv]"
  echo "    -h     print help and exit"
  echo "    -c     pre-req setup for Workload Security:Launch Time Protection - Containers with CRIO Runtime"
  echo "    -v     pre-req setup for Workload Security:Launch Time Protection - VM Confidentiality"
}

dispatch_works() {
  mkdir -p ~/.tmp
  if [[ $1 == *"c"* ]]; then
    echo "Installing Packages for Workload Security:Launch Time Protection - Containers with CRIO Runtime..."
    if [ "$OS" == "rhel" ]; then
      install_prereq_repos_rhel
    fi
    install_prereqs_packages
    install_prereqs_packages_docker
    install_prereq_skopeo
  elif [[ $1 == *"v"* ]]; then
    echo "Installing Packages for Workload Security:Launch Time Protection - VM Confidentiality..."
    if [ "$OS" == "rhel" ]; then
      install_prereq_repos_rhel
    fi
    install_prereqs_packages
  else
    print_help
    exit 1
  fi
}

optstring=":hdcv"
work_list=""
while getopts ${optstring} opt; do
  case ${opt} in
  h)
    print_help
    exit 0
    ;;
  d) work_list+="d" ;;
  c) work_list+="c" ;;
  v) work_list+="v" ;;
  *)
    print_help
    exit 1
    ;;
  esac
done

# run commands
dispatch_works $work_list