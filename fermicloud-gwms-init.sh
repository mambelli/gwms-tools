#!/bin/bash

################################################################################
# TODO:
# 1. Break if there is an error
# 2. Check for existing of my kerberoes principal before starting
# 3. Auto pull ini files and dependencies
################################################################################

####################################################
# Use:
# Customize ini file (initial lines and user dependent lines)
# Run as root
# fermicloud-gwms-init -v GWMS_VERSION -i INIFILE
####################################################

# Set defaults for options
GWMS_VERSION=master
GWMS_INSTANCE=i1
BASE_DIR=/opt
DEV_USER=marcom
#DEV_USER=$USER
HTTP_PORT=8000
INSTALL_TYPE=git
INSTALL_OPTION=""
USER_PROXY=""
# default? ACTION=
# default? INI_FILE=

# Needed in parameter processing 
abspath() {
    # absolute path of $1 (resolving symlinks)
    # readlink does not exist on OSX (is something different)
    rets=`readlink -f $1 2>/dev/null`
    if [ $? -ne 0 ]; then
        rets=$( cd $(dirname $1); pwd)/$(basename $1)
    fi
    echo $rets
}

function help_msg {
  cat << EOF
fermicloud-gwms-init [options] package_list
 -h 		this help text
 -l 		List available versions
 -v VERSION 	Select VERSION in the GIT or TAR repository [Def: master]
                "RC_" prefix in the version means that it is in the release candidates repo
 -r RVERSION 	If used, RVERSION will be used for the path names instead of VERSION
 -e INSTANCE 	Set the INSTANCE, e.g. to have multiple tests of the same version [Def: i1]
 -b DIR		Set base directory [Def: /opt]
 -u USER 	Set the developer USER (for downloads and git) [Def: $DEV_USER]
 -x PROXY 	Path od the user proxy file
 -t      	Install using tarfiles (instead of git)
 -p PORT 	Set HTTP port for monitoring pages
 -i INIFILE 	Ini file used for the configuration
 -o OPTLIST 	Comma separated install options (nopre,nofcrl,...): 
   nopre 	-skip pre-install steps (dload as well)
   nodload 	-skip download and overwrite of aux tarballs and ini files
   nofcrl 	-skip fetch crl invocation
   certforce 	-force relinking of certificate files
   nocode       -skip code download (from git or tar). You must have it already 
   keepini      -keep the ini file as it is without filtering with script options
   norpm        -skip the installation of prerequisite rpm
 package_list is the list of components to install (or all)
EOF
}

# Evaluate options
# check optlist with [[ $optlist == *,opt1,* ]]
while getopts thle:v:r:b:u:x:i:p:o: option
do
  case "${option}"
  in 
  "t") INSTALL_TYPE=tar;;
  "h") help_msg; exit 0;;
  "l") ACTION=list;;
  "e") GWMS_INSTANCE="${OPTARG}";;
  "v") GWMS_VERSION="${OPTARG}";;
  "r") GWMS_VERSION_RENAME="${OPTARG}";;
  "b") BASE_DIR="${OPTARG}";;
  "u") DEV_USER="${OPTARG}";;
  "x") USER_PROXY="${OPTARG}";;
  "i") INI_FILE="${OPTARG}";;
  "p") HTTP_PORT="${OPTARG}";;
  "o") INSTALL_OPTION=",${OPTARG},";;
  esac
done

## MM debug 
# echo " Options ($OPTIND):   t $INSTALL_TYPE,l $ACTION, i $GWMS_INSTANCE, v $GWMS_VERSION, r $GWMS_VERSION_RENAME, b $BASE_DIR, u $DEV_USER, i $INI_FILE, p $HTTP_PORT, o $INSTALL_OPTION"

 

# Remove all the options
shift $(($OPTIND - 1))

#version=$GWMS_VERSI	ON
#MYUSER=$DEV_USER

# This script installs the required pre-reqs and sets up a bare-bone
# FermiCloud VM for glideinwms installation
# GWMS documentation can be found in redmine
# https://cdcvs.fnal.gov/redmine/projects/glideinwms/wiki

export PATH=/sbin:/usr/sbin:$PATH:/usr/local/sbin

###############################################################################
# Some constants
###############################################################################
prereq_rpms="httpd rrdtool rrdtool-python m2crypto git"

# For PACMAN based OSG Client installation
pacman_url="http://atlas.bu.edu/~youssef/pacman/sample_cache/tarballs/pacman-latest.tar.gz"
vdt_location="/usr/local/vdt"

# For RPM OSG Client installation
epel_repo_el5="http://dl.fedoraproject.org/pub/epel/5/x86_64"
epel_repo_el6="http://dl.fedoraproject.org/pub/epel/6/x86_64"

osg_release_el5="http://repo.grid.iu.edu/osg-el5-release-latest.rpm"
osg_release_el6="http://repo.grid.iu.edu/osg-el6-release-latest.rpm"

#GIT repo (git clone...)
#gwms_repo="http://cdcvs.fnal.gov/projects/glideinwms"
gwms_repo="ssh://p-glideinwms@cdcvs.fnal.gov/cvs/projects/glideinwms"
# SVN repo w/ release manager (svn checkout...) 
gwms_relmgr_repo="svn+ssh://p-gwms-release-manager@cdcvs.fnal.gov/cvs/projects/gwms-release-manager"

# For Tar-ball installation
AFS_DIR=/afs/fnal.gov/files/expwww/uscms/html/SoftwareComputing/Grid/WMS/glideinWMS
# gymmic for RC versions
# if GWMS_VERSION starts w/ "RC_", remove the prefix, look in the rc/ AFS directory
if [[ $GWMS_VERSION = RC_* ]]; then 
  AFS_DIR="$AFS_DIR/rc"
  GWMS_VERSION=${GWMS_VERSION:3}
fi

# Rename used for directory names
if [ -z "$GWMS_VERSION_RENAME" ]; then
  GWMS_VERSION_RENAME=$GWMS_VERSION
fi

httpd_port=$HTTP_PORT
# Used in directory names and component names
gwms_version=$GWMS_VERSION_RENAME
# Used in GIT branch/Tar file names
gwms_tag=$GWMS_VERSION

###### Users
# Make sure that the users are consistent with the ini file
# TODO: replace users in ini file
users="gcondor factory frontend testuser vo1user"
test_user="testuser"
# DEV_USER: Developer installing the package and owning the shared files
#dev_user="$DEV_USER"
dev_group="osg"


###### Files and directories

#this will be different for RPM install
httpd_conf="/etc/httpd/conf/httpd.conf"

# Base dir for local users home dirs
local_home="/local/home"


# Directories 
# Files are copied from a shared directory on /grid
# Most action happens locally in subdirecotries of the workdir
# must allow to install multiple version from tarfile or GIT
# Web directories are in /var/www/html
# ~/security

# Downloads dir
downloads_dir="/grid/data/$DEV_USER/glideinwms-autoinstaller"

# Name of the root directory in GIT and TARball distributions
# Consistency is imporant
GWMS_REPO_ROOT_NAME=glideinwms
work_dir="$BASE_DIR"
gwms_location="$work_dir/$GWMS_REPO_ROOT_NAME"
ini_dir="$work_dir/ini"
pkg_dir="$work_dir/installers"
certs_dir="$work_dir/security"

if [[ -z "$INI_FILE" ]]; then
  echo "Ini file not provided, using default $ini_dir/glideinWMS-singlenode.ini"
  INI_FILE="$ini_dir/glideinWMS-singlenode.ini"
else
  INI_FILE=`abspath $INI_FILE`
fi
#echo "Using ini file: $INI_FILE"

# Map of dirs to be created with user as the key
# These can be used only with create_dirs that takes care of ~ substitution
# so that it is the intended home dir and not the user executing the script
declare -a dir_user
dir_user[0]="$local_home $pkg_dir $ini_dir $certs_dir $vdt_location /etc/grid-security"
#dir_user[1]=""
# For the Factory, bersion dependent
# These must be consistent w/ the INI file (factory section)
dir_user[2]="/var/www/html/factory /var/factory/$gwms_version/factorylogs"
# For the frontend
dir_user[3]="/var/www/html/frontend ~/security"
# Security for any other user (e.g. tester)
dir_user[4]="~/security"


###############################################################################
# Functions
###############################################################################

execute() {
    printf "%s\n" "Executing: ${@}"
    eval "$@"
    printf "ExitCode: %d\n" ${?}
}

ts() {
    # It was return ...
    echo `date +%s`
}

create_users() {
    echo "Creating users ..."
    for user in $users
    do
        execute "adduser $user --home-dir $local_home/$user"
    done
    execute "chmod a+rx $local_home/*"
}

customize_httpd() {
    # Remove the auto index
    # set the port (only one w/ this system)
    echo "Customizing httpd.conf (port $1) ..."
    if [ "x$1" != "x" ]; then
        execute "cp $httpd_conf $httpd_conf.`ts`"
        sed -e 's/^Listen/#Listen/g' -e 's/Options Indexes FollowSymLinks/Options FollowSymLinks/g' $httpd_conf >$httpd_conf.$$
        echo "Listen $1" >> $httpd_conf.$$
        execute "mv $httpd_conf.$$ $httpd_conf"
    fi
}

create_dirs() {
    # creating a dir (path) and set ownership
    # handles ~ resolution as the owner user
    directories="$1"
    owner=$2

    echo "Creating dirs $directories for $owner"

    # getent not always there: owner_home=$(getent passwd $owner | cut -d: -f6)
    eval owner_home="$(printf "~%q" "$owner")"
    for dir1 in $directories
    do
         if [[ "$dir1" = '~' || $dir1 == ~\/* ]]; then
             dir="~${owner}${dir1:1}"
#         if [[ $dir1 == ~* ]]; then
#            # Look respectively for: ~, ~/... , ~user...
#            if [[ "$dir1" = '~' || $dir1 == ~\/* ]]; then
#                dir="~${owner}${dir1:1}
#            elif [[ $dir1 == ~\/* ]]; then
#                dir="`echo $dir1 | sed "s!~/!${owner_home}/!"`"
#            else
#                dir="`echo eval "$dir1"`"
#            fi
        else
            dir="$dir1"
        fi        
        execute "mkdir -p $dir"
        if [ -n "$owner" ]; then
            execute "chown $owner $dir"
        fi
    done
}

install_vdt_pacman() {
    # Update maybe w/ CVMFS or tarball install?
    echo "Installing VDT ..."
    cd $work_dir
    execute "wget $pacman_url"
    execute "tar xzf pacman-latest.tar.gz"
    execute "rm pacman-latest.tar.gz"
    execute "cd pacman-*"
    execute "source ./setup.sh"
    cd $vdt_location
    execute "pacman -get http://software.grid.iu.edu/osg-1.2:client"
    execute "source ./setup.sh"
    execute "vdt-ca-manage setupca --location local --url osg"
    execute "vdt-control --disable condor"
    execute "vdt-control --enable fetch-crl vdt-rotate-logs vdt-update-certs"

    execute "vdt-control --on"
    execute "vdt-update-certs --force"
    execute "/usr/local/vdt/fetch-crl/share/doc/fetch-crl-*/fetch-crl.cron"
    ls -la /usr/local/vdt/globus/TRUSTED_CA/*r0
}

install_vdt() {
    # RPM install of OSG client
    # Find if RHEL5 or RHEL6
    kernel_version="`uname -r`"
    if [ "`echo $kernel_version | grep el5`" = "$kernel_version" ]; then
        osg_release=$osg_release_el5
        epel_repo=$epel_repo_el5
    elif [ "`echo $kernel_version | grep el6`" = "$kernel_version" ]; then
        osg_release=$osg_release_el6
        epel_repo=$epel_repo_el6
    else
        osg_release=""
    fi

    # First figure out the latest epel-release rpm in the repo
    epel_rpm_list="/tmp/rpms.$$"
    wget $epel_repo/ --output-document=$epel_rpm_list
    epel_release_rpm=`grep epel-release $epel_rpm_list | awk -F'"' '{print $2}'`
    epel_release="$epel_repo/$epel_release_rpm"

    echo "Installing VDT ..."
    execute "yum clean all"
    execute "yum install --assumeyes $epel_release"
    execute "yum install --assumeyes yum-priorities"
    execute "yum install --assumeyes $osg_release"
    execute "yum install --assumeyes osg-client"
    #execute "fetch-crl"
}

install_afs() {
    # Installation of AFS
    echo "Installing and starting AFS ..."
    execute "yum install --assumeyes openafs-client openafs-krb5"
    execute "service afs start"
    if [ ! -e $AFS_DIR ]; then 
        echo "The AFS dir is not available ($AFS_DIR)"
    fi
}

setup_wspace() {
    # create links to gwms code in all bases of workspaces (TODO: is workspace always in home dir?)
    for user in $users
    do
        su $user -c "mkdir -p ~/$gwms_version"
        su $user -c "ln -s $gwms_location ~/$gwms_version/"
    done
}

setup_gwms_tar() {
    # $1 is the root dir to expand GWMS tar file ($BASE_DIR default)
    if [ "x$1" = "x" ]; then
      tmp_base_dir="$BASE_DIR"
    else
      tmp_base_dir="$1"
    fi
    umask 0022
    if [ ! -e $AFS_DIR ]; then 
        install_afs
    fi    
    cd "$tmp_base_dir"
    execute "tar xzf $AFS_DIR/glideinWMS_${gwms_tag}.tgz"
    cd $GWMS_REPO_ROOT_NAME
    chown -R $DEV_USER.$dev_group "$tmp_base_dir/$GWMS_REPO_ROOT_NAME"
}


setup_gwms_git() {
    # $1 is the root dir to clone GWMS GIT repo ($BASE_DIR default)
    if [ "x$1" = "x" ]; then
      tmp_base_dir="$BASE_DIR"
    else
      tmp_base_dir="$1"
    fi
    umask 0022
    cd "$tmp_base_dir"
    execute "git clone $gwms_repo"
    cd $GWMS_REPO_ROOT_NAME
    execute "git checkout $gwms_tag"
    chown -R $DEV_USER.$dev_group "$tmp_base_dir/$GWMS_REPO_ROOT_NAME"
}

setup_proxies() { 
  # setup the grid proxies
  # Frontend uses a proxy generated by the host cert (other server use the cert directly)
  # Frontend need also a user cert
  # $1 could be the path to the user cert
  if [ "x$1" != "x" ]; then 
    echo "Copying the user certificate"
    execute "cp $1  $certs_dir/user_proxy"
  fi

  execute "voms-proxy-init -cert /etc/grid-security/hostcert.pem -key /etc/grid-security/hostkey.pem -out $certs_dir/grid_proxy -valid 300:0"
  execute "cp $certs_dir/grid_proxy ~frontend/security/grid_proxy"
  execute "chown frontend: ~frontend/security/grid_proxy"
  execute "chmod 0600 ~frontend/security/grid_proxy"
  if [ -f "$certs_dir/user_proxy" ]; then
    execute "cp $certs_dir/user_proxy ~frontend/security/user_proxy"
    execute "chown frontend: ~frontend/security/user_proxy"
    execute "chmod 0600 ~frontend/security/user_proxy"
  else
    echo "No user proxy file: $certs_dir/user_proxy" 
    echo "You need to provide a proxy for the pilot jobs in ~frontend/security/user_proxy"
    # echo "The DN must be consistent with the INI file"
  fi
}

download_condor_and_others(){
    # copying htcondor, javascript and ini files
    execute "cp $downloads_dir/installers/condor*gz $BASE_DIR/installers/"
    execute "cp $downloads_dir/installers/javascript* $BASE_DIR/installers/"
    execute "cp $downloads_dir/ini/* $BASE_DIR/ini/"
    execute "chmod a+r $BASE_DIR/ini/*"
    cd "$BASE_DIR/installers"
    # xargs used to protect against multiple zip files
    ls javascriptrrd*zip | xargs -n1 unzip -o
}

###############################################################################
# Now the real action
###############################################################################

# First check for alt. actions
if [ "x$ACTION" = "xlist" ]; then
  # list available "versions"
  if [ "x$INSTALL_TYPE" = "xtar" ]; then
    echo "Releases Tar files in $AFS_DIR"
    pushd $AFS_DIR > /dev/null
    ls -d glideinWMS*
    echo "Release candidates:"
    ls -d rc/*
    popd > /dev/null
    exit 0
  else
    BASE_DIR=`mktemp -d`
    gwms_location="$BASE_DIR/glideinwms"    
    setup_gwms_git
    echo "Available versions (branches) in GIT:"
    pushd $gwms_location > /dev/null
    git branch -a
    popd > /dev/null
    rm -rf $BASE_DIR 
    exit 0  
  fi 
fi

# pre-install preparation
if [[ $INSTALL_OPTION != *,nopre,* ]]; then 
  # Create root owned required directories
  create_dirs "${dir_user[0]}" "root"

  # Create users
  create_users

  # Create user owned required directories
  #moved out - create_dirs "${dir_user[2]}" "factory"
  create_dirs "${dir_user[3]}" "frontend"
  create_dirs "${dir_user[4]}" "testuser"
fi 

# one of the factory dirs is version dependent, has to be redone all the time
create_dirs "${dir_user[2]}" "factory"
execute "ln -sf /var/www/html/$gwms_version/factory /var/www/html/factory"

if [[ $INSTALL_OPTION != *,nopre,* ]]; then 
  if [[ $INSTALL_OPTION != *,norpm,* ]]; then 
    # Install prereq rpms
    kernel_version="`uname -r`"
    if [ "`echo $kernel_version | grep el5`" = "$kernel_version" ]; then
      execute "yum --enablerepo=dag install -y  $prereq_rpms"
    elif [ "`echo $kernel_version | grep el6`" = "$kernel_version" ]; then
      execute "yum install -y  $prereq_rpms"
    fi
  fi

  # Setup the certificates
  # TODO: These have to be consistent w/ the ini file
  echo "Certificates setup.  Exit code 1 is OK (existing files will not be overwritten)..."
  execute "ln -s /etc/cloud-security/`hostname`-hostcert.pem /etc/grid-security/hostcert.pem"
  execute "ln -s /etc/cloud-security/`hostname`-hostkey.pem /etc/grid-security/hostkey.pem"

  execute "ln -s /etc/grid-security/hostcert.pem /etc/grid-security/condorcert.pem"
  execute "ln -s /etc/grid-security/hostkey.pem /etc/grid-security/condorkey.pem"

  # Install VDT
  if [[ $INSTALL_OPTION != *,norpm,* ]]; then 
    install_vdt
  fi

  # 
  # AFS installed only as needed. Change?
  
  # Download condor and ini files to $BASE_DIR
  if [[ $INSTALL_OPTION != *,nodload,* ]]; then 
    download_condor_and_others
  fi
fi

# Setup the certificates
if [[ $INSTALL_OPTION == *,certforce,* ]]; then 
  # TODO: These have to be consistent w/ the ini file
  echo "Forcing new certificates (overwrite old ones)..."
  execute "ln -sf /etc/cloud-security/`hostname`-hostcert.pem /etc/grid-security/hostcert.pem"
  execute "ln -sf /etc/cloud-security/`hostname`-hostkey.pem /etc/grid-security/hostkey.pem"
  execute "ln -sf /etc/grid-security/hostcert.pem /etc/grid-security/condorcert.pem"
  execute "ln -sf /etc/grid-security/hostkey.pem /etc/grid-security/condorkey.pem"
fi

# fetch-crl must be before the proxies setup. otherwise CRL verification may fail
if [[ $INSTALL_OPTION != *,nofcrl,* ]]; then 
  # Execute fetch-crl
  echo "Running fetch-crl, OK even if ExitCode>0, ..."
  execute "fetch-crl"
fi 

# Setup the proxies
if [[ $INSTALL_OPTION != *,noproxy,* ]]; then 
  setup_proxies $USER_PROXY
fi  

# Change the httpd port and start it
customize_httpd $httpd_port
execute "service httpd restart"

# Setup Glideinwms
if [[ $INSTALL_OPTION != *,nocode,* ]]; then 
  # if the code is there, then backup and let it make a new directory
  # GIT would fail if the clone op if the directory exists
  pushd $BASE_DIR
  if [ -d $GWMS_REPO_ROOT_NAME ]; then
    mv $GWMS_REPO_ROOT_NAME "$GWMS_REPO_ROOT_NAME.bck.`ts`"
  fi
  if [ "x$INSTALL_TYPE" = "xtar" ]; then
    setup_gwms_tar $BASE_DIR
  else
    setup_gwms_git $BASE_DIR
  fi
  popd
fi 

# Setup the dir structure
setup_wspace


#####################################
# Filter the ini file to make it consistent (no ; in key/value)
# gwms version
# hostname

ini_file="$INI_FILE" #ini_dir/glideinWMS-singlenode.ini"

#TODO: some tmo file are leftover in the working directory. Find out what created them
# sed?
filter_ini () {
  TARGET_KEY=$1
  REPLACEMENT_VALUE=$2
  CONFIG_FILE=$3
  sed -c -ibckfilter "s;\($TARGET_KEY *= *\).*;\1$REPLACEMENT_VALUE;" $CONFIG_FILE  
} 

if [[ $INSTALL_OPTION != *,keepini,* ]]; then 
  echo "Filtering ini file $INI_FILE"
  ini_file_tmp=$ini_file.$$
  execute "cp $ini_file $ini_file_tmp"
  # version name
  filter_ini glideinwms_version $GWMS_VERSION_RENAME  $ini_file_tmp
  # used in paths
  filter_ini glideinwms_version1 $GWMS_VERSION  $ini_file_tmp
  filter_ini glideinwms_instance_name $GWMS_INSTANCE  $ini_file_tmp
  #filter_ini javascriptrrd_version $GWMS_  $ini_file_tmp
  #filter_ini condor_version $GWMS_  $ini_file_tmp
  #filter_ini condor_platform $GWMS_  $ini_file_tmp
  filter_ini fqdn `hostname`  $ini_file_tmp
  filter_ini httpd_port $HTTP_PORT  $ini_file_tmp
  filter_ini dev_user $DEV_USER  $ini_file_tmp


  # moving the ini file (and link) to ini_dir that is for sure readable by all
  # original INI_FILE may fail factory and frontend installation
  ini_file="$ini_dir/`basename $ini_file`.`ts`"
  execute "mv $ini_file_tmp $ini_file"
  execute "chmod a+r $ini_file"
  execute "ln -sf $ini_file $ini_dir/`basename ${INI_FILE}`.$GWMS_VERSION_RENAME"
  echo "Ini file to be used in the installation: $ini_file ($ini_dir/`basename ${INI_FILE}`.$GWMS_VERSION_RENAME)"
else
  su factory -c "cat $ini_file > /dev/null"
  if [ $? -ne 0 ]; then
    echo "Ini file ($ini_file) is not publically readable (or its directory is not executable)"
    echo "WARNING: Factory and Frontend installations will fail" 
    # check $@ and exit with error?
  fi
  echo "Ini file to be used in the installation: $ini_file"
fi


#####################################
# Install Glideinwms components

manage_glideins="$gwms_location/install/manage-glideins"

for var in "$@"; do
  echo "Checking parameter $var:"
  case "${var}"
  in 
  "wmsc"|"wmscollector") 
    echo "Installing wmsc"
    $manage_glideins --install wmscollector --ini $ini_file;;
  "userc"|"usercollector") 
    echo "Installing userc"
    $manage_glideins --install usercollector --ini $ini_file ;;
  "sub"|"submit")
    echo "Installing sub"
    $manage_glideins --install submit --ini $ini_file ;;
  "fac"|"factory") 
    echo "Installing fac"
    su factory -c "$manage_glideins --install factory --ini $ini_file" ;;
  "vof"|"fro"|"vofrontend"|"frontend") 
    echo "Installing vof"
    su frontend -c "$manage_glideins --install vofrontend --ini $ini_file" ;;
  "all") 
    echo "Installing all components"
    $manage_glideins --install wmscollector --ini $ini_file
    $manage_glideins --install usercollector --ini $ini_file 
    $manage_glideins --install submit --ini $ini_file 
    su factory -c "$manage_glideins --install factory --ini $ini_file" 
    su frontend -c "$manage_glideins --install vofrontend --ini $ini_file";; 
   *)
    echo "Unknown component option ($var)"
  esac
done

#/opt/glideinwms/install/manage-glideins --install wmscollector --ini /opt/ini/glideinWMS-singlenode.ini

#/opt/glideinwms/install/manage-glideins --install usercollector --ini /opt/ini/glideinWMS-singlenode.ini

#/opt/glideinwms/install/manage-glideins --install submit --ini /opt/ini/glideinWMS-singlenode.ini

#su factory -c "/opt/glideinwms/install/manage-glideins --install factory --ini /opt/ini/glideinWMS-singlenode.ini"

#su frontend -c "/opt/glideinwms/install/manage-glideins --install vofrontend --ini /opt/ini/glideinWMS-singlenode.ini"


echo; echo "-------------- ini file -------------"
echo "The ini file used is:  $ini_file"
echo "To check the status: $manage_glideins --ini $ini_file --status all"


# ======================
# Add sschedd to the daemon list or check with John for everything in one go
# source ~gcondor/v2plus/userpool/condor.sh
# add to config: SEC_ENABLE_MATCH_PASSWORD_AUTHENTICATION = True
#condor_reconfig -full

# ================= Examples
# ./fermicloud-gwms-init.sh -v master_5071 -i ./glideinWMS-singlenode.ini all
# ./fermicloud-gwms-init.sh -v master_5071 -i /opt/ini/glideinWMS-singlenode.ini.1393024565 -o nopre,keepini,nofcrl vof fac
