# Remember, alias are only interactive, not in scriupts w/o: shopt -s expand_aliases
#alias mvim="/Applications/MacVim.app/contents/MacOS/MacVim"
alias mvim="open -a MacVim.app $@"
#alias lt='ls --human-readable --size'
alias lt='du -sh * | sort -h'
alias cpv='rsync -ah --info=progress2'
alias ve='python3 -m venv ./venv'
alias va='source ./venv/bin/activate'
alias dfh='df -h -T hfs,apfs,exfat,ntfs,noowners'
# git
alias cg='cd `git rev-parse --show-toplevel`'
alias cdgwms='cd prog/repos/git-gwms/'
alias cdm='cd-with-memory'
alias pushdm='cd-with-memory pushd'
alias infoalias='
echo -e "Aliases defined:\n General: lt cpv ve va dfh cl cdm pushdm cg"
echo " To connect to fermicloud: fcl... slv slf sgweb fcl-fe-certs"
echo " GWMS: gv.. fe.. fa.."
echo " HTCondor: cv.. cc.. htc_.."
'

## For laptop
# Fermicloud
#alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '. /etc/profile.d/one4x.sh; . /etc/profile.d/one4x_user_credentials.sh; ~marcom/bin/myhosts' > ~/.bashcache/fclhosts"
alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '~marcom/bin/myhosts -r' > ~/.bashcache/fclhosts"
alias fclhosts='cat ~/.bashcache/fclhosts'
alias fclinit='ssh-init-host'
alias fclui='ssh marcom@fermicloudui.fnal.gov'
alias fclvofrontend='ssh root@gwms-dev-frontend.fnal.gov'
alias fclfactory='ssh root@gwms-dev-factory.fnal.gov'
alias fclweb='ssh root@gwms-web.fnal.gov'
alias slv='ssh-last ssh root vofrontend'
alias slf='ssh-last ssh root factory'
alias fcl='ssh-last ssh root'
alias fcl025='ssh root@fermicloud025.fnal.gov' 
#alias sgweb='ssh root@gwms-web.fnal.gov'

## For fermicloud hosts
# GWMS log files
alias gvmain='less /var/log/gwms-frontend/group_main/main.all.log'
alias gvfe='less /var/log/gwms-frontend/frontend/frontend.all.log'
alias gvfa='less /var/log/gwms-factory/server/factory/factory.all.log'
alias gvg0='less /var/log/gwms-factory/server/factory/group_0.all.log'
# HTCondor CondorView some log file, CondorCommand...
alias cvcoll='less /var/log/condor/CollectorLog'
alias cvsched='less /var/log/condor/SchedLog'
alias cvmaster='less /var/log/condor/MasterLog'
alias cvgm='less /var/log/condor/GridManagerLog.schedd_glideins*'
alias cvcerts='less /etc/condor/certs/condor_mapfile'
alias ccs='condor_status -any'
alias ccsf='condor_status -any -af MyType Name'
alias ccq='condor_q -globali -all'
#alias ccql='htc_foreach_schedd condor_q -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccql='htc_foreach_schedd -f1 condor_q -all -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccqlv='htc_foreach_schedd -v -f1 condor_q -all -af ClusterId ProcId GlideinEntryName GlideinClient JobStatus Cmd -name'
alias ccrm='condor_rm -all -name'
alias ccrma='htc_foreach_schedd condor_rm -all -name'

## These are for root on fermicloud hosts
# GWMS manage
alias festart='/bin/systemctl start gwms-frontend'
alias festop='/bin/systemctl stop gwms-frontend'
alias fereconfig='/bin/systemctl stop gwms-frontend; /usr/sbin/gwms-frontend reconfig; /bin/systemctl start gwms-frontend'
alias feupgrade='/bin/systemctl stop gwms-frontend; /usr/sbin/gwms-frontend upgrade; /bin/systemctl start gwms-frontend'
alias fastart='/bin/systemctl start gwms-factory'
alias fastop='/bin/systemctl stop gwms-factory'
alias faupgrade='/bin/systemctl stop gwms-factory; /usr/sbin/gwms-factory upgrade ; /bin/systemctl start gwms-factory'
alias fareconfig='/bin/systemctl stop gwms-factory; /usr/sbin/gwms-factory reconfig; /bin/systemctl start gwms-factory'


## Functions
cl() {
  # cd and list files
  DIR="$*";
  [ $# -lt 1 ] && DIR=$HOME
  builtin cd "${DIR}" && ls -F --color=auto
}

cd-with-memory() {
  # use cd or pushd and record the directory in bash_aliases_aux BA_LASTDIR
  local cmd=cd
  if [[ "$1" = pushd ]]; then
    cmd=pushd
    shift
  fi
  [ ! -e ~/.bash_aliases_aux ] && touch ~/.bash_aliases_aux
  if [ -n "$1" ]; then
    grep -v "^BA_LASTDIR=" ~/.bash_aliases_aux > ~/.bash_aliases_aux.new
    echo "BA_LASTDIR=\"$1\"" >> ~/.bash_aliases_aux.new
    mv ~/.bash_aliases_aux.new ~/.bash_aliases_aux
    $cmd "$1"
  else
    . ~/.bash_aliases_aux
    local lastdir=${BA_LASTDIR}
    if [ -n "$lastdir" ]; then
      [ "$cmd" = cd ] && echo "cd to $lastdir"
      $cmd "$lastdir"
    else
      echo "No last dir available"
      false
    fi
  fi
}

ssh-last() {
  # return the full hostname of the last host of the requested type (or do partial name matches), optionally ssh to it
  # valid types: fact, factory, vofe, frontend, vofrontend, web, ce (fermicloud025), INT (fermicloudINT)
  local dossh=false
  local asroot=false
  if [ "$1" = "ssh" ]; then
    dossh=true
    shift
  fi
  if [ "$1" = "root" ]; then
    asroot=true
    shift
  fi  
  local sel="$1"
  [ "$sel" == "factory" ] && sel=fact
  [ "$sel" == "frontend" ] && sel=vofe
  [ "$sel" == "vofrontend" ] && sel=vofe
  [ "$sel" == "web" ] && sel=gwms-web
  [ "$sel" == "ce" ] && sel=fermicloud025
  [[ "$sel" =~ ^[0-9]+$ ]] && sel="fermicloud$sel"
  myhost=$(grep "$sel" ~/.bashcache/fclhosts | tail -n 1 | cut -d ' ' -f 3 )
  [ -z "$myhost" ] && { echo "Host $1 ($sel) not found on fermiclooud list."; exit 1; }
  shift
  echo $myhost
  if $dossh; then
    if $asroot; then
      ssh root@$myhost "$@"
    else
      ssh $myhost "$@"
    fi
  fi
}

ssh-init-host() {
  # init a fermicloud node
  local hname=$(ssh-last $1)
  local huser=${2:-root}
  echo "Initializing ${huser}@${hname}"
  scp "$HOME"/prog/repos/git-gwms/gwms-tools/.bash_aliases ${huser}@${hname}: >/dev/null && ssh ${huser}@${hname}  ". .bash_aliases && aliases-update"
}

fcl-fe-certs() {
  [[ $(id -u) -ne 0 ]] && { echo "must run as root"; return 1; }
  local pilot_proxy=$1
  [[ -n "$pilot_proxy" ]] && pilot_proxy=/etc/gwms-frontend/mm_proxy
  [[ "$pilot_proxy" = /* ]] || pilot_proxy=/etc/gwms-frontend/"$pilot_proxy"
  pushd /etc/grid-security/
  grid-proxy-init -cert hostcert.pem -key hostkey.pem -valid 999:0 -out /etc/gwms-frontend/fe_proxy
  popd
  /bin/cp /etc/gwms-frontend/fe_proxy /etc/gwms-frontend/vo_proxy
  kx509
  #/bin/cp ~marcom/mm_proxy-now /etc/gwms-frontend/mm_proxy
  voms-proxy-init -rfc -dont-verify-ac -noregen -voms fermilab -valid 500:0
  /bin/cp /tmp/x509up_u0 /etc/gwms-frontend/mm_proxy
  chown frontend: /etc/gwms-frontend/*
  # Check all proxies
  echo "Proxy renewed (/etc/gwms-frontend/vo_proxy, /etc/gwms-frontend/mm_proxy), now checking..."
  if command -v gwms-check-proxies.sh >/dev/null; then
    gwms-check-proxies.sh
  elif [ -x ~marcom/bin/gwms-check-proxies.sh ]; then
    ~marcom/bin/gwms-check-proxies.sh
  else
    echo "No gwms-check-proxies found"
  fi
}

aliases-update() {
  [ -e "$HOME/.bash_aliases" ] && cp "$HOME"/.bash_aliases "$HOME"/.bash_aliases.bck
  if ! curl -L -o $HOME/.bash_aliases https://raw.githubusercontent.com/mambelli/gwms-tools/master/.bash_aliases 2>/dev/null; then
    echo "Download from github.com failed. Update failed."
    return 1
  fi
  if ! grep "# Added by alias-update" $HOME/.bashrc >/dev/null; then
    cat >> $HOME/.bashrc << EOF
# Added by alias-update
export PATH="\$PATH:\$HOME/bin"
if [ -e \$HOME/.bash_aliases ]; then
  source \$HOME/.bash_aliases
fi
# End from alias-update
EOF
  fi
  # copy also some binaries
  mkdir -p "$HOME"/bin
  for i in gwms-clean-logs.sh gwms-setup-script.py gwms-what.sh gwms-check-proxies.sh ; do
    curl -L -o $HOME/bin/$i https://raw.githubusercontent.com/mambelli/gwms-tools/master/$i 2>/dev/null && chmod +x $HOME/bin/$i
  done
  . $HOME/.bash_aliases
}

# HTC functions
htc_job_status() {
  local htc_short=true
  if $htc_short; then
    case $1 in
    0)  echo U;;
    1)  echo  I;;
    2)  echo  R;;
    3)  echo  X;;
    4)  echo  C;;
    5)  echo  H;;
    6)  echo  E;;
    esac
  else
    case $1 in
    0)  echo Unexpanded;;
    1)  echo  Idle;;
    2)  echo  Running;;
    3)  echo  Removed;;
    4)  echo  Completed;;
    5)  echo  Held;;
    6)  echo  Submission_err;;
    esac
  fi
}

htc_filter1() {
  while read -r a b c d e rest; do
    if [[ "$a" == "#"* ]]; then
      echo "$a $b $c $d $e $rest"
    else
      printf '%i.%i\t%s %s %s %s\n' "$a" "$b" "$c" "${d%%-fn*}" "$(htc_job_status "$e")" "$rest"
    fi
  done
}

htc_foreach_schedd() {
  local verbose=false
  local filter=
  if [[ "$1" = "-v" ]]; then
    verbose=true
    shift
  fi
  if [[ "$1" = "-f1" ]]; then
    filter=htc_filter1
    shift
  fi
  local sc_list="$(condor_status -schedd -af Name)"
  for i in $sc_list; do
    $verbose && echo "# $i"
    if [[ -z "$filter" ]]; then
      "$@" $i
    else
      "$@" $i | $filter
    fi
  done
}

