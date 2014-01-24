#!/bin/bash
# From Burt's script

WASRPM=".fromrpm"

if [ "x$1" == "x" ]; then
  G_BRANCH=master
else
  G_BRANCH=$1
fi

if [ "x$2" == "x" ]; then
  # /usr/lib/python2.6/site-packages
  G_ROOTDIR=/opt/gwms
else
  G_ROOTDIR="$2"
fi

if [ -d /usr/lib/python2.6/site-packages/glideinwms${WASRPM} ]; then
  rm -rf /usr/lib/python2.6/site-packages/glideinwms.old
  mv /usr/lib/python2.6/site-packages/glideinwms /usr/lib/python2.6/site-packages/glideinwms.old
else
  mv /usr/lib/python2.6/site-packages/glideinwms /usr/lib/python2.6/site-packages/glideinwms${WASRPM}
fi
cd $G_ROOTDIR
if [ -d glideinwms ];then
  echo "glideinwms directory exists, skipping git cloning and checkout"
else
  git clone http://cdcvs.fnal.gov/projects/glideinwms
  cd glideinwms
  git checkout $G_BRANCH
fi
ln -s $G_ROOTDIR/glideinwms /usr/lib/python2.6/site-packages/glideinwms

sbinfiles="glidecondor_addDN glidecondor_createSecCol glidecondor_createSecSched \
           checkFrontend glidecondor_addDN glidecondor_createSecCol \
           glidecondor_createSecSched glideinFrontendElement.py \
           reconfig_frontend stopFrontend"

binfiles="glidein_cat glidein_gdb glidein_interactive glidein_ls glidein_ps glidein_status \
          glidein_top wmsTxtView wmsXMLView"

# Separate because the name is different
if [ -f /usr/sbin/glideinFrontend${WASRPM} ];then
  rm -f /usr/sbin/glideinFrontend.old
  mv /usr/sbin/glideinFrontend /usr/sbin/glideinFrontend.old
else
  mv /usr/sbin/glideinFrontend /usr/sbin/glideinFrontend${WASRPM}
fi
real_loc=`find $G_ROOTDIR/glideinwms -type f -name glideinFrontend.py`
ln -s ${real_loc} /usr/sbin/glideinFrontend

for x in $sbinfiles
  do
    if [ -f /usr/sbin/${x}${WASRPM} ];then
      rm -f /usr/sbin/${x}.old
      mv /usr/sbin/${x} /usr/sbin/${x}.old
    else
      mv /usr/sbin/${x} /usr/sbin/${x}${WASRPM}
    fi
    real_loc=`find $G_ROOTDIR/glideinwms -type f -name $x\*`
    ln -s ${real_loc} /usr/sbin/${x}
done

for x in $binfiles
  do
    if [ -f /usr/bin/${x}${WASRPM} ];then
      rm -f /usr/bin/${x}.old
      mv /usr/bin/${x} /usr/bin/${x}.old
    else
      mv /usr/bin/${x} /usr/bin/${x}${WASRPM}
    fi
    real_loc=`find $G_ROOTDIR/glideinwms -type f -name $x\*`
    ln -s ${real_loc} /usr/bin/${x}
done
