#!/bin/bash
BASEDIR=/opt/oldlog
SOURCEDIR=~marcom/data/glideinwms-autoinstaller/aux/

mydate="`date +"%Y%m%d-%H%M%S-%s"`"
function clean_condor {
  condor_dir="$BASEDIR/condor-$mydate"
  mkdir "$condor_dir"
  pushd /var/log/condor > /dev/null
  mv *Log* KernelTuning.log "$condor_dir"/
  echo "Logs moved to $condor_dir"
  popd > /dev/null
}

function clean_gwms_fe {
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-frontend > /dev/null
  mv frontend/frontend*log $gwms_dir/
  mv frontend/startup.log $gwms_dir/
  mv group_main/main*log $gwms_dir/
  echo "Logs moved to $gwms_dir"
  popd > /dev/null
}

function clean_gwms_fa {
  gwms_dir="$BASEDIR/gwms-$mydate"
  mkdir "$gwms_dir"
  pushd /var/log/gwms-factory > /dev/null
  mv server/factory/factory*log $gwms_dir/
  mv server/factory/group*log $gwms_dir/
  echo "Logs moved to $gwms_dir"
  popd > /dev/null
}

function print_help {
  cat << EOF 
$0 [options]
Clean (i.e. rotate to old directory) HTCondor and GWMS (frontend or factory) logs
-h 	print this message
-d 	set HTCondor debug
-D 	remove HTCondor debug
EOF
}

##### SCRIPT STARTS #######
# Setup

# TODO: use getopt if there are more options
# -h help
# -d set debug (condor)
# -D remove debug (condor)

if [ "$1" = "-h" ]; then
  print_help
  exit 0
fi
 
if [ "$1" = "-d" ]; then
  SETDEBUG=yes
fi
if [ "$1" = "-D" ]; then
  NODEBUG=yes
fi

mkdir -p "$BASEDIR"

# HTCondor
echo "Cleaning HTCondor"
service condor stop
[ -n "$NODEBUG" ] && echo "Unset HTCondor debug" && rm /etc/condor/config.d/99_debug.config
[ -n "$SETDEBUG" ] && echo "Enable HTCondor debug" && cp "$SOURCEDIR"/99_debug.config /etc/condor/config.d/99_debug.config
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





