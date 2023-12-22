#!/bin/bash
#
# curl -sL https://raw.githubusercontent.com/CyBerNetX/schleuder-web-debian-sh/main/install.sh |bash -s -- -h
# http://192.168.1.123:3000
#
# $SUDO systemctl status schleuder-api-daemon.service
# $SUDO systemctl status schleuder-web.service 
#
START="$(date +%s)"
LOGDIR="./log"
LOG="$LOGDIR/Installation_schleuder-web_$(date +%F_%H%M%S).log"
[ "$DEBUG" == 'true' ] && set -x
SUDO=/usr/bin/sudo
#
NORMAL=`echo "\033[m"`
BLUE=`echo "\033[36m"` #Blue
YELLOW=`echo "\033[33m"` #yellow
FGRED=`echo "\033[41m"`
RED_TEXT=`echo "\033[31m"`
ENTER_LINE=`echo "\033[33m"`
Red=`echo "\033[0;31m"`
Green=`echo "\033[32m"`

nc="\033[00m"
red="\033[01;31m"
green="\033[01;32m"
yellow="\033[01;33m"
blue="[debug]\033[01;34m"
purple="\033[01;35m"
cyan="\033[01;36m"

MAINCF="/etc/postfix/main.cf"
DOVCOTECONFD=/etc/dovecot/conf.d/10-master.conf
export VARTMP=/tmp/schleuderweb.tmp

SCHLEUDER_BIN=$(whereis -b schleuder|cut -d" " -f2)

SCHLEUDER="/etc/schleuder/"
SCHLEUDER_WEB_VAR_DEFAULT="/etc/default/schleuder-web"
SCHLEUDER_WEB_SERVICE="/etc/systemd/system/schleuder-web.service"
SCHLEUDER_WEB_LAUNCHER="/etc/systemd/system/launcher_schleuder-web.sh"
SCHLEUDER_API_HOST="127.0.0.1"
SCHLEUDER_API_PORT="4443"
# default constant values
cat <<"VAROEF" > $VARTMP
NORMAL=`echo "\033[m"`
YELLOW=`echo "\033[33m"`
yellow="\033[01;33m"
RED_TEXT=`echo "\033[31m"`
Red=`echo "\033[0;31m"`
UTILISATEUR=schleuder-web
SCHLEUDER_WEB="/home/$UTILISATEUR/schleuder-web/"
# Fonction pour vérifier si la commande a réussi
check_command() {
    if [ $? -ne 0 ]; then
        echo "Erreur ($?): La commande a échoué. Arrêt de l'installation."
        DURATION=$[ $(date +%s) - ${START} ]
        TZ=UTC0 printf 'temps de fonctionement du script : %(%H:%M:%S)T\n' ${DURATION}
        exit 1
    fi
}
VAROEF
chmod 777 $VARTMP
. $VARTMP
cat $VARTMP
sleep 5

logo="${cyan}Author :${green} 
${blue}                  ____      ____            _   _      _${green}  __  __
${blue}                 / ___|   _| __ )  ___ _ __| \ | | ___| |_${green}\ \/ /
${blue}                | |  | | | |  _ \ / _ \ '__|  \| |/ _ \ __|${green}\  / 
${blue}                | |__| |_| | |_) |  __/ |  | |\  |  __/ |_ ${green}/  \ 
${blue}                 \____\__, |____/ \___|_|  |_| \_|\___|\__${green}/_/\_\ 
${blue}                      |___/                                     
${cyan} A Crypted mailing list for everyone 
${nc}"

mkdir -p "$LOGDIR"
exec > >(tee -a "$LOG" ) 2>&1


function usage(){
        echo "$0 [ -l liste.exemple.org | -o exemple.org ]"
        echo " -l : liste domaine"
        echo " -o : domaine original "
        echo ""
        echo "$0 -h "
        echo "    help"
        echo ""
        exit 0  
}

function confpostfix(){
  if [[ ! -z $(grep virtual_transport ${MAINCF}|grep dovecot) ]] 
  then
    [[ -z $(grep "dovecot:lmtp" ${MAINCF}) ]] && sed -i "s#\(virtual_transport\) = \(dovecot\)#\1 = \2:lmtp#g" ${MAINCF}
  
    [[ ! -e  ${DOVECOTCONFD} ]] && cat <<"EOFDOVECOT" | $SUDO tee ${DOVECOTCONFD}
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
EOFDOVECOT

    [[ -z $(grep "schleuder_transport" ${MAINCF} ) ]] && cat<<"EOFMAINSCHLEUDER" |$SUDO  tee -a ${MAINCF}
schleuder_transport = schleuder
schleuder_destination_recipient_limit = 1
EOFMAINSCHLEUDER

  elif [[ ! -e $(grep virtual_transport ${MAINCF} ) ]] 
  then
    cat <<"EOFMAINPOSTFIX" |$SUDO tee -a ${MAINCF}
virtual_transport = schleuder
schleuder_destination_recipient_limit = 1
EOFMAINPOSTFIX
  
  fi
}


function main_schleuder(){
        echo -e "$logo"
        sleep 5
        

        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${Red} Updates et upgrades ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5

        $SUDO apt-get update && $SUDO apt-get upgrade -y
        check_command
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${Red} Installation des applications ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        $SUDO apt-get install -y schleuder 
        check_command
        
        #$SUDO  sed -i "s/superadmin: root@localhost/superadmin: root@$ORIGINDOMAIN/g"  ${SCHLEUDER}schleuder.yml
        $SUDO  sed -i "s/host: localhost/host: ${SCHLEUDER_API_HOST}/g"  ${SCHLEUDER}schleuder.yml
        $SUDO  sed -i "s/port: 4443/port: ${SCHLEUDER_API_PORT}/g"  ${SCHLEUDER}schleuder.yml

        $SUDO systemctl restart schleuder-api-daemon.service
        check_command
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT}  Config postfix pour schleuder ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5

        [[ -z $(grep schleuder /etc/postfix/master.cf) ]] && (echo -e "schleuder  unix  -       n       n       -       -       pipe\n  flags=DRhu user=schleuder argv=$SCHLEUDER_BIN work \${recipient}"|$SUDO  tee -a  /etc/postfix/master.cf)
        
        [[ -z $(grep sqlite:/etc/postfix/schleuder_domain_sqlite.cf /etc/postfix/main.cf) ]] && (sed -i "s#\(virtual_mailbox_domains = \)\(.*\)#\1\2,sqlite:/etc/postfix/schleuder_domain_sqlite.cf#g" /etc/postfix/main.cf)
        [[ -z $(grep hash:/etc/postfix/virtual_aliases /etc/postfix/main.cf) ]] && (sed -i "s#\(virtual_alias_maps = \)\(.*\)#\1\2,hash:/etc/postfix/virtual_aliases#g" /etc/postfix/main.cf) 
        [[ -z $(grep sqlite:/etc/postfix/schleuder_list_sqlite.cf /etc/postfix/main.cf) ]] && (sed -i "s#\(virtual_mailbox_maps = \)\(.*\)#\1\2,sqlite:/etc/postfix/schleuder_list_sqlite.cf#g" /etc/postfix/main.cf)
        
        confpostfix

        [[ ! -e /etc/postfix/schleuder_domain_sqlite.cf ]] && cat << EOF |$SUDO  tee -a /etc/postfix/schleuder_domain_sqlite.cf 
dbpath = /var/lib/schleuder/db.sqlite
query = select distinct substr(email, instr(email, '@') + 1) from lists
        where email like '%%%s'
EOF

        [[ ! -e /etc/postfix/schleuder_list_sqlite.cf ]] && cat <<AOF |$SUDO  tee -a /etc/postfix/schleuder_list_sqlite.cf 
dbpath = /var/lib/schleuder/db.sqlite
query = select 'present' from lists
        where email = '%s'
        or    email = replace('%s', '-bounce@', '@')
        or    email = replace('%s', '-owner@', '@')
        or    email = replace('%s', '-request@', '@')
        or    email = replace('%s', '-sendkey@', '@')
AOF


        [[ ! -e /etc/postfix/virtual_aliases ]] && cat <<BOF |$SUDO  tee -a /etc/postfix/virtual_aliases 
postmaster@$LISTS    root@$ORIGINDOMAIN
abuse@$LISTS         root@$ORIGINDOMAIN
MAILER-DAEMON@$LISTS root@$ORIGINDOMAIN
root@$LISTS          root@$ORIGINDOMAIN
BOF

        $SUDO postmap /etc/postfix/virtual_aliases
        check_command

        $SUDO systemctl restart postfix
        check_command
}

function main_schleuderweb(){

        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} # Creation user et prerequis ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        
        # Nom de l'utilisateur spécifié en argument
        
        $SUDO useradd -r -m -d /home/$UTILISATEUR -s /bin/bash -c "Schleuder Web GPG-mailing list manager mode web" $UTILISATEUR
        $SUDO apt install -y autoconf patch build-essential rustc libssl-dev libyaml-dev libreadline6-dev zlib1g-dev libgmp-dev libncurses5-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev uuid-dev libxml2-dev libsqlite3-dev openssl
        $SUDO apt install -y curl git
        $SUDO groupadd -f gems
        $SUDO usermod -aG gems $UTILISATEUR
        
        [[ ! -e /var/lib/gems/ ]] && $SUDO mkdir -p /var/lib/gems/
        $SUDO chown :gems /var/lib/gems/
        $SUDO chmod g+sw /var/lib/gems/
        #---------- user schleuder ---------#
        $SUDO VARTMP=$VARTMP -i -u $UTILISATEUR  <<"END_SWSA"

. $VARTMP
echo -e "${yellow} [==============================] ${NORMAL}"
cd ~/
echo $PWD
echo $PATH
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} # Installation de Ruby avec rbenv ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

git clone https://github.com/rbenv/rbenv.git ~/.rbenv
check_command
echo 'PATH="$PATH:~/.rbenv/bin"' >> ~/.profile
echo 'export PATH' >> ~/.profile
echo 'eval "$(rbenv init --no-rehash -)"' >> ~/.profile
export PATH="~/.rbenv/shims:~/.rbenv/bin:$PATH"


echo -e "${yellow} [==============================] ${NORMAL}"
cd ~/
echo $PWD
echo $PATH
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5


echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} # Installation de Ruby-build (plugin pour rbenv) ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
check_command
echo $PATH
END_SWSA

        $SUDO VARTMP=$VARTMP -i -u $UTILISATEUR  <<"END_SWSC"

. $VARTMP
echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} # Installation de Ruby ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

rbenv install 2.7.4
check_command
rbenv global 2.7.4
check_command

echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} # Installation de Bundler ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

echo ":ipv4_fallback_enabled: true" | $SUDO tee -aplu ~/.gemrc

gem install bundler -v 2.4.22
check_command

echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} Déploiement source schleuder-web ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

# Installation de Schleuder-web
git clone https://0xacab.org/schleuder/schleuder-web.git $SCHLEUDER_WEB
check_command
echo -e "${yellow} $SCHLEUDER_WEB ${NORMAL}"
cd $SCHLEUDER_WEB


echo -e "${Red} installation de schleuder-web : ${NORMAL}"

echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} Install ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

#bundle install --without development
echo -e "${RED_TEXT} bundle update --bundler ${NORMAL}"
bundle update --bundler
check_command
echo -e "${RED_TEXT} bundle set $SCHLEUDER_WEB ${NORMAL}"
bundle config set --local path $SCHLEUDER_WEB
check_command
bundle config set --local without 'development'
check_command
echo -e "${RED_TEXT} bundle install ${NORMAL}"
bundle install
check_command

echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} Creation SECRET_KEY_BASE ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5
echo -e "${yellow} $PWD ${NORMAL}"
export SECRET_KEY_BASE=$(bin/rails secret)
check_command

echo -e "${Red} SECRET_KEY_BASE=$SECRET_KEY_BASE${NORMAL}"
echo -e "export SECRET_KEY_BASE=$SECRET_KEY_BASE" >>$VARTMP
END_SWSC
        check_command
        
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Creation SCHLEUDER_TLS_FINGERPRINT ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        export SCHLEUDER_TLS_FINGERPRINT=$($SUDO  schleuder cert fingerprint|cut -d" " -f4)
        check_command

        echo -e "${Red} 
        SCHLEUDER_TLS_FINGERPRINT=$SCHLEUDER_TLS_FINGERPRINT${NORMAL}"
       echo -e "export SCHLEUDER_TLS_FINGERPRINT=$SCHLEUDER_TLS_FINGERPRINT" >>$VARTMP
       
        
        $SUDO systemctl restart schleuder-api-daemon.service
        check_command
        

        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Creation SCHLEUDER_API_KEY ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        export SCHLEUDER_API_KEY=$($SUDO  schleuder new_api_key)
        check_command
        
        $SUDO sed -i "s/# shared:/shared:\n  api_key: ${SCHLEUDER_API_KEY}/g" ${SCHLEUDER_WEB}config/secrets.yml

        echo -e "${Red} SCHLEUDER_API_KEY=$SCHLEUDER_API_KEY${NORMAL}"
        echo -e "export SCHLEUDER_API_KEY=$SCHLEUDER_API_KEY" >>$VARTMP


        $SUDO sed -i "s/  valid_api_keys:/  valid_api_keys:\n    - ${SCHLEUDER_API_KEY}/g" ${SCHLEUDER}schleuder.yml

        grep ${SCHLEUDER_API_KEY} ${SCHLEUDER}schleuder.yml



        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Var schleuder-web ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        . $VARTMP



        echo -e "[Service]
SCHLEUDER_API_HOST=$SCHLEUDER_API_HOST
SCHLEUDER_API_PORT=$SCHLEUDER_API_PORT
SCHLEUDER_API_KEY=$SCHLEUDER_API_KEY
SCHLEUDER_TLS_FINGERPRINT=$SCHLEUDER_TLS_FINGERPRINT
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_ENV=production" | tee ${SCHLEUDER_WEB_VAR_DEFAULT}

        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Service schleuder-web ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "#!/bin/bash
. /home/${UTILISATEUR}/.profile
cd ${SCHLEUDER_WEB}
./bin/bundle exec rails server" | $SUDO  tee ${SCHLEUDER_WEB_LAUNCHER}
        $SUDO chmod 755 ${SCHLEUDER_WEB_LAUNCHER}

        echo -e "[Unit]
Description=Schleuder Web
After=local-fs.target network.target schleuder-api-daemon.service

[Service]
EnvironmentFile=${SCHLEUDER_WEB_VAR_DEFAULT}
WorkingDirectory=${SCHLEUDER_WEB}
User=$UTILISATEUR
ExecStart=${SCHLEUDER_WEB_LAUNCHER}  
[Install]
WantedBy=multi-user.target" | $SUDO  tee ${SCHLEUDER_WEB_SERVICE}

        $SUDO chmod 755 ${SCHLEUDER_WEB_SERVICE}
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Setup ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        $SUDO VARTMP=$VARTMP -i -u $UTILISATEUR <<"END_SWSB"

. $VARTMP
cd $SCHLEUDER_WEB
bundle exec rake db:setup RAILS_ENV=production
echo -e "${yellow} [==============================] ${NORMAL}"
echo -e "${RED_TEXT} Precompile ${NORMAL}"
echo -e "${yellow} [==============================] ${NORMAL}"
sleep 5

RAILS_ENV=production bundle exec rake assets:precompile
END_SWSB
        check_command
        echo -e "${yellow} [==============================] ${NORMAL}"
        echo -e "${RED_TEXT} Execution ${NORMAL}"
        echo -e "${yellow} [==============================] ${NORMAL}"
        sleep 5
        $SUDO systemctl daemon-reload
        check_command
        $SUDO systemctl enable schleuder-web.service 
        check_command
        $SUDO systemctl restart schleuder-api-daemon.service
        check_command
        $SUDO systemctl start schleuder-web.service 
        check_command  
        YNHBIN=$(whereis -b yunohost|cut -d":" -f2|cut -d" " -f2)
        [[ ! -z $YNHBIN ]] && $SUDO $YNHBIN app install redirect -l Schleuder -a "domain=$LISTS&path=/&redirect_type=public_proxy&redirect_path=http://127.0.0.1:3000"
        echo -e "${BLUE} Visit http://$(hostname -I|awk '{print $1}'):3000/${NORMAL}"
        echo -e "${yellow} compte : $($SUDO grep superadmin ${SCHLEUDER}schleuder.yml |cut -d":" -f2) ${NORMAL}"
        echo -e "${yellow} Password : slingit! ${NORMAL}"
        $SUDO rm $VARTMP
        DURATION=$[ $(date +%s) - ${START} ]
        TZ=UTC0 printf 'temps de fonctionement du script : %(%H:%M:%S)T\n' ${DURATION}
        exit 0
}

no_args="true"
while getopts l:o:h option
do 
  case "${option}"
        in
        l) LISTS=${OPTARG};;
        o) ORIGINDOMAIN=${OPTARG};;
        h) usage ;;
        *) usage ;;
  esac
  no_args="false"
done
[[ "$no_args" == "true" ]] && { usage; exit 1; }
main_schleuder
main_schleuderweb
