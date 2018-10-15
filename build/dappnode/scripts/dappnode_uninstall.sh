#!/bin/bash

DAPPNODE_DIR="/usr/src/dappnode/"
DAPPNODE_CORE_DIR="${DAPPNODE_DIR}DNCORE/"
LOG_PATH="./dappnode_uninstall.log"

mkdir -p $DAPPNODE_DIR
mkdir -p $DAPPNODE_CORE_DIR
mkdir -p "${DAPPNODE_CORE_DIR}scripts"
mkdir -p "${DAPPNODE_CORE_DIR}build"

if [ "$NAME" = "Ubuntu" ];then
    WGET='wget -q --show-progress '
else
    WGET='wget '
fi

function setup_profile() {
	PROFILE_URL="https://raw.githubusercontent.com/dappnode/DAppNode_Installer/master/build/scripts/.dappnode_profile"
	PROFILE_FILE="${DAPPNODE_CORE_DIR}.dappnode_profile"

	[ -f $PROFILE_FILE ] || $WGET -O $PROFILE_FILE $PROFILE_URL 2>&1 | tee -a $LOG_PATH
	source "${PROFILE_FILE}"
}

function setup_components() {
	components=(BIND IPFS ETHCHAIN ETHFORWARD VPN WAMP DAPPMANAGER ADMIN)

	# The indirect variable expansion used in ${!ver##*:} allows us to use versions like 'dev:development'
	# If such variable with 'dev:'' suffix is used, then the component is built from specified branch or commit.
	for comp in "${components[@]}"; do
	    ver="${comp}_VERSION"
	    eval "${comp}_URL=\"https://github.com/dappnode/DNP_${comp}/releases/download/v${!ver}/${comp,,}.dnp.dappnode.eth_${!ver}.tar.xz\""
	    eval "${comp}_YML=\"https://github.com/dappnode/DNP_${comp}/releases/download/v${!ver}/docker-compose-${comp,,}.yml\""
	    eval "${comp}_YML_FILE=\"${DAPPNODE_CORE_DIR}docker-compose-${comp,,}.yml\""
	    eval "${comp}_FILE=\"${DAPPNODE_CORE_DIR}${comp,,}.dnp.dappnode.eth_${!ver##*:}.tar.xz\""
	done
}

function setup_dappnode_core_yml() {
    for comp in "${components[@]}"; do
        ver="${comp}_VERSION"
        if [[ ${!ver} != dev:* ]]; then
            # Download DAppNode Core docker-compose yml files if it's needed
            eval "[ -f \$${comp}_YML_FILE ] || $WGET -O \$${comp}_YML_FILE \$${comp}_YML"
        fi
    done
}

function remove_dappnode_packages() {
    find /var/lib/docker/volumes/dncore_dappmanagerdnpdappnodeeth_data/_data -name "*yml"  | xargs -I {} docker-compose -f {} down  --rmi 'all' -v
}

function disconnect_containers() {
    docker container ls -a -q -f name=DAppNode* | xargs -I {} docker network disconnect --force dncore_network {} 2>/dev/null
}

function wipe_containers_volumes_and_images() {
	docker-compose -f $BIND_YML_FILE -f $IPFS_YML_FILE -f $ETHCHAIN_YML_FILE -f $ETHFORWARD_YML_FILE -f $VPN_YML_FILE -f $WAMP_YML_FILE -f $DAPPMANAGER_YML_FILE -f $ADMIN_YML_FILE down  --rmi 'all' -v
}

function remove_source_folder() {
	rm -rf /usr/src/dappnode
}

function remove_profile() {
	# Remove profile file
	USER=$(cat /etc/passwd | grep 1000  | cut -f 1 -d:)
	[ ! -z $USER ] && PROFILE=/home/$USER/.profile || PROFILE=/root/.profile  
	sed -i '/########          DAPPNODE PROFILE          ########/g' $PROFILE
	sed -i '/.*dappnode_profile/g' $PROFILE
}

##############################################
##############################################
####             SCRIPT START             ####
##############################################
##############################################

echo -e "\e[32m\n##############################################\e[0m" 2>&1 | tee -a $LOG_PATH
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_PATH
echo -e "\e[32m####         DAPPNODE UNINSTALLER         ####\e[0m" 2>&1 | tee -a $LOG_PATH
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_PATH
echo -e "\e[32m##############################################\e[0m" 2>&1 | tee -a $LOG_PATH


echo -e "\e[32mSetting up profile...\e[0m" 2>&1 | tee -a $LOG_PATH
setup_profile

echo -e "\e[32mSetting up DAppNode components...\e[0m" 2>&1 | tee -a $LOG_PATH
setup_components

echo -e "\e[32mSetting up DAppNode control YML files...\e[0m" 2>&1 | tee -a $LOG_PATH
setup_dappnode_core_yml

echo -e "\e[32mRemoving DAppNode packages...\e[0m" 2>&1 | tee -a $LOG_PATH
remove_dappnode_packages

echo -e "\e[32mDisconnecting containers...\e[0m" 2>&1 | tee -a $LOG_PATH
disconnect_containers

echo -e "\e[32mWiping containers, volumes and images...\e[0m" 2>&1 | tee -a $LOG_PATH
wipe_containers_volumes_and_images

echo -e "\e[32mRemoving source folder...\e[0m" 2>&1 | tee -a $LOG_PATH
remove_source_folder

echo -e "\e[32mRemoving profile...\e[0m" 2>&1 | tee -a $LOG_PATH
remove_profile

echo -e "\e[32mDAppNode uninstalled!\e[0m" 2>&1 | tee -a $LOG_PATH

exit 0
