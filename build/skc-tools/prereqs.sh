declare -a PRE_REQ_URLS
PRE_REQ_URLS=(
https://dl.fedoraproject.org/pub/fedora/linux/releases/30/Everything/x86_64/os/Packages/m/makeself-2.4.0-3.fc30.noarch.rpm
)

declare -a PRE_REQ_PACKAGES
PRE_REQ_PACKAGES=(
wget
gcc
gcc-c++
ant
git
zip
java-1.8.0-openjdk-devel.x86_64
make
)

#download pre-reqs
download_prereqs() {
  local error_code=0
  dnf install -y yum-utils
  for url in ${!PRE_REQ_URLS[@]}; do
    local package_url=${PRE_REQ_URLS[${url}]}
    wget --delete-after --no-check-certificate ${package_url}
    local return_code=$?
    if [ ${return_code} -ne 0 ]; then
      echo "ERROR: could not download [${package_url}]"
      return ${return_code}
    fi
  done
 
  return ${error_code}
}

#install pre-reqs
install_prereqs() {
  local error_code=0

  for package in ${!PRE_REQ_PACKAGES[@]}; do
    local package_name=${PRE_REQ_PACKAGES[${package}]}
    dnf install -y ${package_name}
    local return_code=$?
    if [ ${return_code} -ne 0 ]; then
      echo "ERROR: could not install [${package_name}]"
      return ${return_code}
    fi
  done
   
  return ${error_code}
}

# functions handling i/o on command line
print_help() {
    echo "Usage: $0 [-his]"
    echo "    -h    print help and exit"
    echo "    -s    pre-req setup"
}

dispatch_works() {
    mkdir ~/.tmp
    if [[ $1 = *"s"* ]] ; then
        download_prereqs
        install_prereqs
    fi
}

if [ $# -eq 0 ] ; then
    print_help
    exit 1
fi

OPTIND=1
work_list=""
while getopts his opt; do
    case ${opt} in
    h)  print_help; exit 0 ;;
    s)  work_list+="s" ;;
    *)  print_help; exit 1 ;;
    esac
done

# run commands
dispatch_works $work_list
