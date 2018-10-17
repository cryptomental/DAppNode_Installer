#!/bin/bash
set -euo pipefail

DAPPNODE_DIR="/opt/dappnode/"
DAPPNODE_CORE_DIR="${DAPPNODE_DIR}DNCORE/"
LOG_DIR="${DAPPNODE_DIR}dappnode_install.log"

mkdir -p $DAPPNODE_DIR
mkdir -p $DAPPNODE_CORE_DIR
mkdir -p "${DAPPNODE_CORE_DIR}scripts"

PROFILE_URL="https://raw.githubusercontent.com/cryptomental/DAppNode_Installer/master/build/scripts/.dappnode_profile"
PROFILE_FILE="${DAPPNODE_CORE_DIR}.dappnode_profile"

source /etc/os-release

if [ "$NAME" = "Ubuntu" ];then
    WGET="wget -q --show-progress "
else
    WGET="wget "
fi

[ -f $PROFILE_FILE ] || ${WGET} -O ${PROFILE_FILE} ${PROFILE_URL}

source "${PROFILE_FILE}"

components=(BIND IPFS ETHCHAIN ETHFORWARD VPN WAMP DAPPMANAGER ADMIN)

# The indirect variable expansion used in ${!ver##*:} allows us to use versions like 'dev:development'
# If such variable with 'dev:'' suffix is used, then the component is built from specified branch or commit.
for comp in "${components[@]}"; do
    ver="${comp}_VERSION"
    eval "${comp}_URL=\"https://github.com/cryptomental/DNP_${comp}/releases/download/v${!ver}/${comp,,}.dnp.dappnode.eth_${!ver}.tar.xz\""
    eval "${comp}_YML=\"https://github.com/cryptomental/DNP_${comp}/releases/download/v${!ver}/docker-compose-${comp,,}.yml\""
    eval "${comp}_YML_FILE=\"${DAPPNODE_CORE_DIR}docker-compose-${comp,,}.yml\""
    eval "${comp}_FILE=\"${DAPPNODE_CORE_DIR}${comp,,}.dnp.dappnode.eth_${!ver##*:}.tar.xz\""
done

dappnode_core_build()
{
    for comp in "${components[@]}"; do
        ver="${comp}_VERSION"
        file="${comp}_FILE"
        if [[ ${!ver} == dev:* ]]; then
            echo "Cloning & building DNP_${comp}..."
            pushd $DAPPNODE_CORE_DIR
            git clone -b "${!ver##*:}" https://github.com/cryptomental/DNP_${comp}
            # Change version in YAML to the custom one
            sed -i "s~^\(\s*image\s*:\s*\).*~\1${comp,,}.dnp.dappnode.eth:${!ver##*:}~" DNP_${comp}/docker-compose-${comp,,}.yml
            docker-compose -f ./DNP_${comp}/docker-compose-${comp,,}.yml build
            cp ./DNP_${comp}/docker-compose-${comp,,}.yml $DAPPNODE_CORE_DIR
            rm -r ./DNP_${comp}
            popd
        fi
    done
}

dappnode_core_download()
{
    for comp in "${components[@]}"; do
        ver="${comp}_VERSION"
        if [[ ${!ver} != dev:* ]]; then
            # Download DAppNode Core Images if it's needed
            eval "[ -f \$${comp}_FILE ] || $WGET -O \$${comp}_FILE \$${comp}_URL"
            # Download DAppNode Core docker-compose yml files if it's needed
            eval "[ -f \$${comp}_YML_FILE ] || $WGET -O \$${comp}_YML_FILE \$${comp}_YML"
        fi
    done
}

dappnode_core_load()
{
    for comp in "${components[@]}"; do
        ver="${comp}_VERSION"
        if [[ ${!ver} != dev:* ]]; then
            eval "[ ! -z \$(docker images -q ${comp,,}.dnp.dappnode.eth:${!ver##*:}) ] || docker load -i \$${comp}_FILE 2>&1 | tee -a \$LOG_DIR"
        fi
    done

    # Delete build line from yml
    sed -i '/build: \.\/build/d' $DAPPNODE_CORE_DIR/*.yml 2>&1 | tee -a $LOG_DIR
}

addSwap()
{
    # Is swap enabled?
    IS_SWAP=$(swapon --show | wc -l)

    # if not then create it
    if [ $IS_SWAP -eq 0 ]; then
        echo 'Swap not found. Adding swapfile.'
        #RAM=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
        #SWAP=$(($RAM * 2))
        SWAP=8388608
        fallocate -l ${SWAP}k /swapfile
        chmod 600 /swapfile
        mkswap /swapfile
        swapon /swapfile
        echo '/swapfile none swap defaults 0 0' >> /etc/fstab
    else
        echo 'swapfile found. No changes made.'
    fi
}

dappnode_start()
{
    echo -e "\e[32mDAppNode starting...\e[0m" 2>&1 | tee -a $LOG_DIR
    docker-compose -f $BIND_YML_FILE -f $IPFS_YML_FILE -f $ETHCHAIN_YML_FILE -f $ETHFORWARD_YML_FILE -f $VPN_YML_FILE -f $WAMP_YML_FILE -f $DAPPMANAGER_YML_FILE -f $ADMIN_YML_FILE up -d 2>&1 | tee -a $LOG_DIR
    echo -e "\e[32mDAppNode started\e[0m" 2>&1 | tee -a $LOG_DIR

    # Show credentials to the user on login
    USER=$(cat /etc/passwd | grep 1000  | cut -f 1 -d:)
    [ ! -z $USER ] && PROFILE=/home/$USER/.profile || PROFILE=/root/.profile

    if [ ! "$(grep ".dappnode_profile" $PROFILE)" ];then
        echo "########          DAPPNODE PROFILE          ########" >> $PROFILE
        echo -e "source ${DAPPNODE_CORE_DIR}.dappnode_profile\n" >> $PROFILE
    fi

    sed -i '/return/d' $PROFILE_FILE| tee -a $LOG_DIR
    echo "docker exec DAppNodeCore-vpn.dnp.dappnode.eth getAdminCredentials" >> $PROFILE_FILE
    echo "echo -e \"\n\e[32mOnce connected through the VPN (L2TP/IPSec) you can access to the administration console by following this link:\e[0m\"" >> $PROFILE_FILE
    echo "echo -e \"\nhttp://my.admin.dnp.dappnode.eth/\n\"" >> $PROFILE_FILE
    echo -e "return\n" >> $PROFILE_FILE

    # Delete dappnode_install.sh execution from rc.local if exists
    if [ -f "/etc/rc.local" ];then
        sed -i '/\/opt\/dappnode\/scripts\/dappnode_install.sh/d' /etc/rc.local 2>&1 | tee -a $LOG_DIR
    fi
}

##############################################
##############################################
####             SCRIPT START             ####
##############################################
##############################################

echo -e "\e[32m\n##############################################\e[0m" 2>&1 | tee -a $LOG_DIR
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_DIR
echo -e "\e[32m####          DAPPNODE INSTALLER          ####\e[0m" 2>&1 | tee -a $LOG_DIR
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_DIR
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_DIR

echo -e "\e[32mCreating swap memory...\e[0m" 2>&1 | tee -a $LOG_DIR
addSwap

echo -e "\e[32mBuilding DAppNode Core if needed...\e[0m" 2>&1 | tee -a $LOG_DIR
dappnode_core_build

echo -e "\e[32mDownloading DAppNode Core...\e[0m" 2>&1 | tee -a $LOG_DIR
dappnode_core_download

echo -e "\e[32mLoading DAppNode Core...\e[0m" 2>&1 | tee -a $LOG_DIR
dappnode_core_load

echo -e "\e[32mDAppNode installed\e[0m" 2>&1 | tee -a $LOG_DIR
dappnode_start

[ ! -f "/opt/dappnode/iso_install.log" ] && source "${PROFILE_FILE}"

exit 0

