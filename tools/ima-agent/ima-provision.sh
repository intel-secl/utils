#!/bin/bash

set -e

ascii_file='/sys/kernel/security/ima/ascii_runtime_measurements'
grub_tboot_file='/etc/grub.d/20_linux_tboot'
grub_cfg_file='/boot/efi/EFI/redhat/grub.cfg'
grub_cmdline_file='/proc/cmdline'
custom_obj_file='isecl.pp'

if [[ ! -d "/sys/kernel/security/ima" ]]; then
    echo "Ima is not enabled. Please recompile the kernel with the ima config option enabled"
    exit 1
fi    

# Display the usage
display_usage() {
    echo "$0 set-custom-policy -i [filelist] --hash [sha256]"
    echo "set-custom-policy - This option will create the SElinux custom object type and assign to the specific directory"
    echo "$0 appraise [fix] --hash [sha256]"
    echo "appraise - This option will prep the grub command line for fix mode"
    echo "$0 measure [enable] --hash [sha256]"
    echo "measure - This option will set the grub command line to measure the TCB"
    echo "$0 [gen-measurements]"
    echo "gen-measurements - This option will label based on ima policy and generate the measurements in ascii file"
    exit $1
}

declare -a appraiseMethods=("fix")
declare -a measureMethods=("enable")
declare -a hashAlgorithms=("sha256")

# Validate if the input appraise options are correct
check_if_appraise_is_valid() {
    isValid=0
    for val in ${appraiseMethods[@]}; do
        if [[ $val == $1 ]]; then
            isValid=1
        fi
    done
    if [[ $isValid == 0 ]]; then
        echo "Invalid ima_appraise option"
        display_usage 1
    fi
}

# Validate if the input measure options are correct
check_if_measure_is_valid() {
    isValid=0
    for val in ${measureMethods[@]}; do
        if [[ $val == $1 ]]; then
            isValid=1
        fi
    done
    if [[ $isValid == 0 ]]; then
        echo "Invalid ima_measure option"
        display_usage 1
    fi
}

# Validate if the input hash options are correct
check_if_hash_is_valid() {
    isValid=0
    for val in "${hashAlgorithms[@]}"; do
        if [[ $val == $1 ]]; then
            isValid=1
        fi
    done
    if [[ $isValid == 0 ]]; then
        echo "Invalid ima_hash option"
        display_usage 1
    fi
}

# Update the ima-policy to exclude logs and frequently changed data files
update_tcb_policy() {
    policy_dir=/etc/ima
    if [[ ! -d $policy_dir ]]; then
        mkdir -p $policy_dir
    fi
    # Copy the policy file under ima folder
    cp tcb-policy-file $policy_dir/ima-policy
}

# Update the custom ima-policy 
update_custom_policy() {
    echo "Updating the ima custom policy.."
    output=$(yum list installed selinux-policy-devel)
    if ! grep -q "selinux-policy-devel" <<< $output; then
        echo "Please install selinux-policy-devel package to set the custom policy"
        exit 1
    fi

    echo "Reverting back the existing custom object type on files"
    while read -r line ; do
    file_name=`echo $line | cut -d " " -f 5`
    if [[ $file_name == "boot_aggregate" ]]; then
        continue
    fi;
    restorecon $file_name
    done <$ascii_file

    if [ $? -eq 0 ]; then
        echo "Reverting existing object type is successful"
    else
        echo "Failed to revert the existing object type on files"
        exit 1
    fi;  

    echo "Creating the custom object type.."
    make -f /usr/share/selinux/devel/Makefile $custom_obj_file

    echo "Importing the custom object type to the node.."
    semodule -i $custom_obj_file

    echo "Assigning the object type to directory or file.."
    while read -r line; do
        chcon -R -t isecl_t $line # By using this command, user can apply object type to any dir                             
    done <$file_list

    policy_dir=/etc/ima
    if [[ ! -d $policy_dir ]]; then
        mkdir -p $policy_dir
    fi
    # Copy the policy file under ima folder
    cp custom-policy-file $policy_dir/ima-policy
}

# Label the system
label_system() {
    find / \( -fstype rootfs -o -fstype ext3 -o -fstype ext4 -o -fstype xfs \) -type f -print0 | while read -d $'\0' file; do
        head -n 1 "$file" >/dev/null
    done
}

# Validate if the ima_appraise is set or not
check_ima_appraise_mode() {
    if ! grep -q -e 'ima_appraise=fix' "$grub_cmdline_file"; then
        echo "To set ima_policy for measurements, ima_appraise=fix need to be set first"
        exit 1
    fi
}

# Validate if the ima_policy=tcb is set or not
check_ima_policy_mode() {
    if ! grep -q -e 'ima_policy=tcb' "$grub_cmdline_file"; then
        echo "To generate tcb measurements in json format, ima_policy = tcb need to be set first"
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    appraise)
        appraise_mode=1
        ima_appraise=${2,,}
        check_if_appraise_is_valid $ima_appraise
        shift 2
        ;;

    measure)
        measure_mode=1
        ima_measure=${2,,}
        check_if_measure_is_valid $ima_measure
        shift 2
        ;;

    --hash)
        hash=${2,,}
        check_if_hash_is_valid $hash
        shift 2
        ;;

    set-custom-policy)
        custom_policy=1
        shift
        ;;

    -i)
        if [[ $custom_policy -eq 0 ]]; then 
            echo "Invalid argument"
            display_usage 1
            exit 1   
        fi        
        if [[ ! -z $2 ]]; then
            input_file=1
            file_list=$2
	    if [ ! -f "$file_list" ]; then
	 	echo "File $file_list not found!" >&2
		exit 1
	    fi
        else
            echo "Please provide input file list that contains directory/file path to set the custom policy"
            display_usage 1
            exit 1
        fi
        shift 2
        ;;

    gen-measurements)
        ima_generate=1
        shift
        ;;

    *)
        if [ $1 != '--help' ]; then
            echo "Invalid option: $1"
        fi
        display_usage 0
        break
        ;;
    esac
done

# Check if any ima option flag is present
if [[ $custom_policy -eq 0 && $ima_generate -eq 0 && -z ${ima_appraise+x} && -z ${ima_measure+x} ]]; then
   echo "Any one of the ima option flags is mandatory"
  display_usage 1
fi

# Check if hash argument is absent or empty
# If hash is not provided, set default hash as sha256
if [[ $ima_generate -eq 0 && -z ${hash+x} ]]; then
    hash="sha256"
    echo "Hash is not provided. Setting the default hash $hash"
fi

if [[ $custom_policy -eq 1 ]]; then
    if [[ $input_file -eq 1 ]]; then
        grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="ima_template=ima-ng ima_hash=${hash}"
        if [ ! -f "$grub_tboot_file" ]; then
            echo "File $grub_tboot_file not found!" >&2
            echo "Tboot is not enabled in the host"
        else
            echo "Tboot is enabled in the host"
            if ! grep -q -e 'ima_template=ima-ng' "$grub_cmdline_file"; then
                echo "Updating tboot grub file with IMA parameters"
                to_find="GRUB_CMDLINE_LINUX_TBOOT="
                replace=": $"{"GRUB_CMDLINE_LINUX_TBOOT='intel_iommu=on ima_template=ima-ng ima_hash=${hash}'"}""

                sed -i "s/.*${to_find}.*/${replace}/g" $grub_tboot_file
                if [ $? -eq 0 ]; then
                    echo "Updating tboot grub file with IMA parameters is successful"
                else
                    echo "Failed to update tboot grub file with IMA parameters"
                    exit 1
                fi

                echo "Taking backup of existing grub.cfg"
                if [ ! -f "$grub_cfg_file" ]; then
                    echo "File $grub_cfg_file not found!" >&2
                    exit 1
                fi
                cp $grub_cfg_file $grub_cfg_file.bak

                echo "Updating grub to include IMA parameters to tboot boot option"
                grub2-mkconfig -o $grub_cfg_file
                if [ $? -eq 0 ]; then
                    echo "Updating grub is successful"
                    echo "Warning : Reboot the host once script ran succesfully and boot to tboot option from boot menu"
                else
                    echo "Failed to update grub. So reverting back $grub_cfg_file"
                    mv $grub_cfg_file.bak $grub_cfg_file 
                    exit 1
                fi
            else
                echo "IMA parameters are already set"
            fi
	    fi
        update_custom_policy        
    else
        echo "Please provide input file list that contains directory/file path to set the custom policy"
        display_usage 1
        exit 1
    fi
elif [[ $measure_mode -eq 1 && $appraise_mode -eq 0 ]]; then
    check_ima_appraise_mode
    # Set the ima measure and ima hash in the grubby command line
    grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="ima_policy=tcb ima_template=ima-ng ima_hash=${hash}"
    update_tcb_policy
elif [[ $appraise_mode -eq 1 && $measure_mode -eq 0 ]]; then
    # Set the ima appraise and ima hash in the grubby command line
    grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="ima_appraise=fix ima_template=ima-ng ima_hash=${hash}"
elif [[ $appraise_mode -eq 1 && $measure_mode -eq 1 ]]; then
    grubby --update-kernel=/boot/vmlinuz-$(uname -r) --args="ima_appraise=fix ima_policy=tcb ima_template=ima-ng ima_hash=${hash}"
    update_tcb_policy
fi

if [[ $? -gt 0 ]]; then
    echo "Error setting the ima appraise or measure mode"
    exit 1
fi

#***********generate_measurements**************
if [[ $ima_generate -eq 1 ]]; then
    echo "Started labelling the file system... It will take a few minutes"
    label_system
    echo "Finished labelling...!"
else
    echo "Reboot the system for the changes to take effect"
fi
