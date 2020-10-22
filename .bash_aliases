#alias mvim="/Applications/MacVim.app/contents/MacOS/MacVim"
alias mvim="open -a MacVim.app $@"
#alias lt='ls --human-readable --size'
alias lt='du -sh * | sort -h'
alias cpv='rsync -ah --info=progress2'
alias ve='python3 -m venv ./venv'
alias va='source ./venv/bin/activate'
alias dfh='df -h -T hfs,apfs,exfat,ntfs,noowners'
# fermicloud
#alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '. /etc/profile.d/one4x.sh; . /etc/profile.d/one4x_user_credentials.sh; ~marcom/bin/myhosts' > ~/.bashcache/fclhosts"
alias fclrefreshhosts="ssh -K marcom@fermicloudui.fnal.gov  '~marcom/bin/myhosts -r' > ~/.bashcache/fclhosts"
alias fclhosts='cat ~/.bashcache/fclhosts'
alias fclui='ssh marcom@fermicloudui.fnal.gov'
alias fclvofrontend='ssh root@gwms-dev-frontend.fnal.gov'
alias fclfactory='ssh root@gwms-dev-factory.fnal.gov'
alias fclweb='ssh root@gwms-web.fnal.gov'
alias slv='ssh-last ssh root vofrontend'
alias slf='ssh-last ssh root factory'
alias fcl='ssh-last ssh root'
alias fcl025='ssh root@fermicloud025.fnal.gov' 
#alias sgweb='ssh root@gwms-web.fnal.gov'
# git
alias cg='cd `git rev-parse --show-toplevel`'


## functions
cl() {
  DIR="$*";
  [ $# -lt 1 ] && DIR=$HOME
  builtin cd "${DIR}" && ls -F --color=auto
}

ssh-last() {
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
  ~marcom/bin/check-proxies
}

aliases-update() {
  [ -e "$HOME/.bash_aliases" ] && cp "$HOME"/.bash_aliases "$HOME"/.bash_aliases.bck
  curl -L -o $HOME/.bash_aliases https://raw.githubusercontent.com/mambelli/gwms-tools/master/.bash_aliases
  if ! grep "# Added by alias-update" $HOME/.bash_profile; then
    cat >> $HOME/.bash_profile << EOF
# Added by alias-update
export PATH="$PATH:$HOME/bin"
if [ -e $HOME/.bash_aliases ]; then
  source $HOME/.bash_aliases
fi
# End from alias-update
EOF
  fi
  # copy also some binaries
  for i in gwms-clean-logs.sh gwms-setup-script.py gwms-what.sh gwms-check-proxies.sh ; do
    curl -L -o $HOME/bin/$i https://raw.githubusercontent.com/mambelli/gwms-tools/master/$i
    chmod +x $HOME/bin/$i
  done
  . $HOME/.bash_aliases
}
