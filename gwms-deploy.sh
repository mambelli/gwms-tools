#!/bin/bash
BASEDIR=/opt/gwms-alt
RPMDIR=/opt/gwms-rpm
PYTHONDIR="`python -c 'import glideinwms; print glideinwms.__path__[0]'`"
SOURCEDIR=~marcom/data/glideinwms-autoinstaller/aux/
OLDLOGDIR=/opt/oldlog

MYFULLPATH=get_realpath $0 
MYATVAR=$@

mydate="`date +"%Y%m%d-%H%M%S-%s"`"


# from https://github.com/AsymLabs/realpath-lib
# via http://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself
function get_realpath {
    [[ ! -f "$1" ]] && return 1  # failure : file does not exist.
    [[ -n "$no_symlinks" ]] && local pwdp='pwd -P' || local pwdp='pwd'  # do symlinks.
    echo "$( cd "$( echo "${1%/*}" )" 2>/dev/null; $pwdp )"/"${1##*/}"  # echo result.
    return 0  # success
}


function prep_rpm_vofe {
  # First time to backup RPM files
  #TODO: Backup with same structure so it can be linked back
  if [ -d "$RPMDIR" ]; then
    echo "RPM files already transferred, skipping"
  else
    mkdir -p "$RPMDIR"/usr_sbin_py
    pushd /usr/sbin
    mv checkFrontend glideinFrontendElement.py glideinFrontend stopFrontend "$RPMDIR"/usr_sbin_py/
    for i in checkFrontend glideinFrontend stopFrontend; do 
      ln -s "$PYTHONDIR"/frontend/${i}.py $i
    done
    ln -s "$PYTHONDIR"/frontend/glideinFrontendElement.py glideinFrontendElement.py

    mkdir "$RPMDIR"/usr_sbin
    mv glidecondor_addDN glidecondor_createSecCol glidecondor_createSecSched "$RPMDIR"/usr_sbin/
    for i in glidecondor_addDN glidecondor_createSecCol glidecondor_createSecSched ; do 
      ln -s "$BASEDIR"/glideinwms/install/$i $i 
    done

    mkdir "$RPMDIR"/usr_bin_py
    cd /usr/bin/
    mv /usr/bin/glidein* "$RPMDIR"/usr_bin_py
    for i in glidein_cat  glidein_gdb  glidein_interactive  glidein_ls  glidein_ps  glidein_status  glidein_top; do  
      ln -s "$PYTHONDIR"/tools/${i}.py $i
    done

    cd "`dirname "$PYTHONDIR"`"
    mv glideinwms "$RPMDIR"/py_glideinwms
    mkdir glideinwms
    cd glideinwms/
    for i in creation  frontend  __init__.py  lib  tools; do  ln -s "$BASEDIR"/glideinwms/$i $i; done
    # this should be done in new deployments too

    # no touching files in /etc

    cd /var/lib/gwms-frontend/
    mkdir "$RPMDIR"/var_lib_gwms-frontend 
    mv creation web-base "$RPMDIR"/var_lib_gwms-frontend 
    ln -s "$BASEDIR"/glideinwms/creation creation
    ln -s "$BASEDIR"/glideinwms/creation/web_base web-base

  fi
}


function refresh_vofe {
  # After each new deployment
  if [ ! -f "$BASEDIR"/glideinwms/creation/creation ]; then
    pushd "$BASEDIR"/glideinwms/creation/
      ln -s . creation
    popd
  fi

  #vi /etc/gwms-frontend/frontend.xml
  # Works in both SL6/7
  service gwms-frontend upgrade
  service gwms-frontend reconfig
}

function prep_rpm_fact {
  # First time to backup RPM files
  #TODO: Backup with same structure so it can be linked back
  if [ -d "$RPMDIR" ]; then
    echo "RPM files already backed up, skipping"
  else
    pushd /usr/sbin
    #mkdir /opt/old_usrsbin
    mkdir -p "$RPMDIR"/usr_sbin_py

    mv checkFactory.py* glideFactoryEntryGroup.py* glideFactoryEntry.py* glideFactory.py* manageFactoryDowntimes.py* stopFactory.py* "$RPMDIR"/usr_sbin/
    for i in checkFactory.py glideFactoryEntryGroup.py glideFactoryEntry.py glideFactory.py manageFactoryDowntimes.py stopFactory.py; do 
      ln -s "$PYTHONDIR"/factory/$i $i
      ln -s "$PYTHONDIR"/factory/${i}o ${i}o 
      ln -s "$PYTHONDIR"/factory/${i}c ${i}c
    done

    # already in: pushd /usr/sbin
    mkdir -p "$RPMDIR"/usr_sbin
    mv clone_glidein glidecondor_createSecCol glidecondor_addDN glidecondor_createSecSched info_glidein reconfig_glidein "$RPMDIR"/usr_sbin
    ## Not in factory  mv reconfig_frontend /opt/fromrpm/usr_sbin   # reconfig_frontend is not there at start
    for i in glidecondor_createSecCol glidecondor_addDN glidecondor_createSecSched; do 
      ln -s "$BASEDIR"/glideinwms/install/$i $i 
    done
    for i in clone_glidein info_glidein reconfig_glidein reconfig_frontend; do 
      ln -s "$BASEDIR"/glideinwms/creation/$i $i
    done

    mkdir "$RPMDIR"/usr_bin_py
    mv /usr/bin/glidein* "$RPMDIR"/usr_bin_py/
    cd /usr/bin/
    for i in glidein_cat glidein_gdb glidein_interactive glidein_ls glidein_ps glidein_status glidein_top; do  
      ln -s "$PYTHONDIR"/tools/${i}.py $i 
    done

    cd "`dirname "$PYTHONDIR"`"
    mv glideinwms "$RPMDIR"/py_glideinwms
    mkdir glideinwms
    cd glideinwms/
    for i in creation  factory  __init__.py  lib  tools; do  ln -s "$BASEDIR"/glideinwms/$i $i; done

    # no touching files in /etc

    cd /var/lib/gwms-factory/
    mkdir "$RPMDIR"/var_lib_gwms-factory
    mv creation web-base "$RPMDIR"/var_lib_gwms-frontend 
    ln -s "$BASEDIR"/glideinwms/creation creation
    ln -s "$BASEDIR"/glideinwms/creation/web_base web-base

    # purge logs?
    #cd /var/log/gwms-factory/
    #mkdir old
    #mv client server old
    #mkdir client server
    #chown gfactory: server

    popd
  fi

}

function refresh_fact {
  # After each new deployment
  if [ ! -f "$BASEDIR"/glideinwms/creation/creation ]; then
    pushd "$BASEDIR"/glideinwms/creation/
      ln -s . creation
    popd
  fi

  #vi /etc/gwms-frontend/frontend.xml
  # Works in both SL6/7
  service gwms-factory upgrade
  service gwms-factory reconfig
}


function prep_git {
  if yum list installed git >/dev/null 2>&1; then
    echo "git already installed"
  else
    yum install -y git
  fi
  if [ -e /opt/gwms-git ]; then
    rm -rf /opt/gwms-git.old >/dev/null 2>&1
    mv /opt/gwms-git /opt/gwms-git.old
  fi
  mkdir /opt/gwms-git
  pushd /opt/gwms-git
  git clone ssh://p-glideinwms@cdcvs.fnal.gov/cvs/projects/glideinwms
  # you may need a kinit if the key was not forwarded
  if [ -n "$1" ]; then 
    cd glideinwms
    git checkout $1
  fi
  popd
}

function prep_tar {
  # note that this is not a normal GWMS tar ball installation
  if [ -e /opt/gwms-tar ]; then
    rm -rf /opt/gwms-tar.old >/dev/null 2>&1
    mv /opt/gwms-tar /opt/gwms-tar.old
  fi
  mkdir /opt/gwms-tar
  pushd /opt/gwms-tar
  git clone ssh://p-glideinwms@cdcvs.fnal.gov/cvs/projects/glideinwms
  # you may need a kinit if the key was not forwarded
  if [ -d "$1" ]; then 
    cp -r "$1" /opt/gwms-tar/
  elif [ -f "$1" ]; then
    tar xzf "$1"
  else
    echo "No valid file or directory provided [$1]. Aborting deployment"
    exit 1
  fi
  popd
}



function clean_condor {
  local condor_dir="$OLDLOGDIR/condor-$mydate"
  mkdir "$condor_dir"
  pushd /var/log/condor > /dev/null
  mv *Log* KernelTuning.log "$condor_dir"/
  echo "Logs moved to $condor_dir"
  popd > /dev/null
}

function clean_gwms_fe {
  local gwms_dir="$OLDLOGDIR/gwms-$mydate"
  mkdir -p "$gwms_dir"
  pushd /var/log/gwms-frontend > /dev/null
  mv frontend/frontend*log $gwms_dir/
  mv frontend/startup.log $gwms_dir/
  mv group_main/main*log $gwms_dir/
  echo "Frontend logs moved to $gwms_dir"
  popd > /dev/null
}

function clean_gwms_fa {
  local gwms_dir="$OLDLOGDIR/gwms-$mydate"
  mkdir -p "$gwms_dir"
  pushd /var/log/gwms-factory > /dev/null
  mv server/factory/factory*log $gwms_dir/
  mv server/factory/group*log $gwms_dir/
  echo "Factory logs moved (no client and entries) to $gwms_dir"
  popd > /dev/null
}

function clean_gwms_fa_deep {
  local gwms_dir="$OLDLOGDIR/gwms-$mydate"
  mkdir -p "$gwms_dir"
  pushd /var/log/gwms-factory > /dev/null
  mv client server $gwms_dir/
  mkdir client server
  chown gfactory: server
  echo "ALL Factory logs moved (including client and entries) to $gwms_dir"
  popd > /dev/null
}


function remote_invocation {
  #echo "Not working yet!"
  #exit 0
  # tar
  # send tar and script
  # invoke script with -R and -p remote file path
  dsthost=$1
  [ ${#dsthost} -eq 3 ] && dsthost="fermicloud${dsthost}.fnal.gov"
  scp $MYFULLPATH ${dsthost}:/tmp/gwms_deployment_${mydate}_$$.sh
  if [ -z "$DOTAR" ]; then
    echo "Running remote script"
    ssh ${dsthost} /tmp/gwms_deployment_${mydate}_$$.sh -R $MYATVAR    
  else
    srcpath="$2"
    [ -z "$srcpath" ] && srcpath="`dirname "`pwd`"`"
    echo "Deploying $srcpath to $dsthost"
    if [ -d "$srcpath" ]; then
      tmpfname=gwms_deployment_${mydate}_$$.tgz
      tar czf /tmp/$tmpfname "$srcpath"
      srcpath=/tmp/$tmpfname
    fi
    scp $srcpath ${dsthost}:/tmp/gwms_deployment_${mydate}_$$.tgz
    ssh ${dsthost} /tmp/gwms_deployment_${mydate}_$$.sh -R -P /tmp/gwms_deployment_${mydate}_$$.tgz $MYATVAR
    # ssh ${dsthost} /bin/rm /tmp/gwms_deployment_${mydate}_$$.tgz
  fi
  # ssh ${dsthost} /bin/rm /tmp/gwms_deployment_${mydate}_$$.sh 
  echo "Deployed"
  
}

function help_msg {
  cat << EOF
$0 [options]  
Clean log file and/or deploy GWMS from git or a source tree
  -h       print this help message
  -v       verbose
  -d       enable HTCondor debug 
  -D       disable HTCondor debug
  -c       clean and backup old log files
  -l LIST  comma separated list of components to clean (default:cond,fact,vofe). All:cond,fact,vofe,entries
  -g       setup deploy GWMS from git on a RPM installation (RPM files are backed up)
  -b NAME  deploy the NAME branch (default: master). Used only with -g
  -t       deploy the current directory (by packaging, sending and expanding)
  -p PNAME deploy the PNAME file (if it is a file) or PNAME directory (default: \$PWD). Used only with -t
  -r HOST  run the commands (deployment/cleaning) on HOST instead of locally
           3 character HOST becomes fermicloudHOST.fnal.gov
These options are used by the remote invocation. Users should not need them:
  -R       the script has been called by the remote invocation
  -P PNAME path on the remote host, overriding the deployment path from invocation (-p)
EOF
}

##### SCRIPT STARTS #######
# Setup

# Default values
CLEANLIST="cond,fact,vofe"
# Option "-R" added to the remote invocation to avoid infinite recursion

while getopts "hdDcl:gb:tp:r:Rv" option
do
  case "${option}"
  in
  "h") help_msg; exit 0;;
  "v") VERBOSE=yes;;
  d) SETDEBUG=yes;;
  D) NODEBUG=yes;;
  c) DOCLEAN=yes;;
  g) DOGIT=yes;;
  t) DOTAR=yes;;
  l) CLEANLIST=$OPTARG;;
  b) GITBRANCH=$OPTARG;;
  p) TARPATH=$OPTARG;;
  r) REMOTE=$OPTARG;;
  P) TARPATHOVERRIDE=$OPTARG;;  
  R) IAMREMOTE=yes;;
  esac
done

# TODO: check for conflicting options/sanity check


# Override used in remote invocation
[ -n "$TARPATHOVERRIDE" ] && TARPATH="$TARPATHOVERRIDE"

if [ -n "$REMOTE" ]; then 
  if [ -z "$IAMREMOTE" ]; then
    remote_invocation $REMOTE $TARPATH
  
# TODO: abs path of TARPATH

if [ -n "${SETDEBUG}${NODEBUG}" ]; then
  service condor stop
  [ -n "$NODEBUG" ] && echo "Unset HTCondor debug" && rm /etc/condor/config.d/99_debug.config
  [ -n "$SETDEBUG" ] && echo "Enable HTCondor debug" && cp "$SOURCEDIR"/99_debug.config /etc/condor/config.d/99_debug.config
  service condor start
fi


if [ -n "$DOCLEAN" ]; then

  mkdir -p "$OLDLOGDIR"

  #TODO: add check for CLEANLIST, use it

  # HTCondor
  echo "Cleaning HTCondor"
  service condor stop
  clean_condor
  service condor start

  # GWMS
  if [ -e /etc/gwms-frontend/frontend.xml ]; then
    echo "Cleaning frontend"
    service gwms-frontend stop
    clean_gwms_fe
    service gwms-frontend start
  fi

  if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
    echo "Cleaning factory"
    service gwms-factory stop
    clean_gwms_fa
    service gwms-factory start
  fi

fi


if [ -n "$DOGIT" ]; then
  prep_git $GITBRANCH
  ln -sf /opt/gwms-git /opt/gwms-alt
fi

if [ -n "$DOTAR" ]; then
  prep_tar $TARPATH
  ln -sf /opt/gwms-tar /opt/gwms-alt
fi

if [ -n "${DOGIT}${DOTAR}" ]; then 

  # Disable GWMS auto update
  grep 'EXCLUDE="glidein' /etc/sysconfig/yum-autoupdate > /dev/null && sed -i.bak 's/^EXCLUDE="/EXCLUDE="glidein* /' /etc/sysconfig/yum-autoupdate 

  # Setup rpm->alt
  if [ -e /etc/gwms-frontend/frontend.xml ]; then
    echo "Setting up alt frontend"
    prep_rpm_vofe
    refresh_vofe
  fi

  if [ -e /etc/gwms-factory/glideinWMS.xml ]; then
    echo "Setting up alt factory"
    prep_rpm_fact
    refresh_fact
  fi

fi  

