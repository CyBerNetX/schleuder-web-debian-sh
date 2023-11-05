#!/bin/bash
#
# curl -sL https://raw.githubusercontent.com/CyBerNetX/schleuder-web-debian-sh/main/install.sh |bash -s --
# http://192.168.1.123:3000
#
# sudo systemctl status schleuder-api-daemon.service
# sudo systemctl status schleuder-web.service 
#
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

# default constant values

logo="${cyan}Author :${green} 
${blue}                  ____      ____            _   _      _${green}  __  __
${blue}                 / ___|   _| __ )  ___ _ __| \ | | ___| |_${green}\ \/ /
${blue}                | |  | | | |  _ \ / _ \ '__|  \| |/ _ \ __|${green}\  / 
${blue}                | |__| |_| | |_) |  __/ |  | |\  |  __/ |_ ${green}/  \ 
${blue}                 \____\__, |____/ \___|_|  |_| \_|\___|\__${green}/_/\_\ 
${blue}                      |___/                                     
${cyan} A Crypted mailing list for everyone 
${nc}"



echo -e "$logo"
sleep 3
SCHLEUDER_WEB="/var/www/schleuder-web/"
SCHLEUDER="/etc/schleuder/"
SCHLEUDER_WEB_VAR_DEFAULT="/etc/default/schleuder-web"
SCHLEUDER_WEB_SERVICE="/etc/systemd/system/schleuder-web.service"
SCHLEUDER_API_HOST="127.0.0.1"
SCHLEUDER_API_PORT="4443"

$SUDO apt-get update && $SUDO apt-get upgrade -y
echo -e "${Red} Installation des applications ${NORMAL}"
$SUDO apt-get install -y schleuder 

$SUDO apt install -y ruby-bundler libxml2-dev zlib1g-dev libsqlite3-dev ruby-full build-essential git ruby-dev openssl libssl-dev

$SUDO  sed -i "s/host: localhost/host: ${SCHLEUDER_API_HOST}/g"  ${SCHLEUDER}schleuder.yml
$SUDO  sed -i "s/port: 4443/port: ${SCHLEUDER_API_PORT}/g"  ${SCHLEUDER}schleuder.yml

$SUDO systemctl restart schleuder-api-daemon.service

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW}  Config postfix pour schleuder ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"


[[ -z $(grep schleuder /etc/postfix/master.cf) ]] && (echo -e "schleuder  unix  -       n       n       -       -       pipe\n  flags=DRhu user=schleuder argv=/path/to/bin/schleuder work ${recipient}"|$SUDO  tee -a  /etc/postfix/master.cf)

[[ -z $(grep schleuder /etc/postfix/main.cf) ]] && ( echo -e " \n
schleuder_destination_recipient_limit = 1\n\
virtual_mailbox_domains = sqlite:/etc/postfix/schleuder_domain_sqlite.cf\n\
virtual_transport       = schleuder\n\
virtual_alias_maps      = hash:/etc/postfix/virtual_aliases\n\
virtual_mailbox_maps    = sqlite:/etc/postfix/schleuder_list_sqlite.cf"|$SUDO  tee -a /etc/postfix/main.cf)

[[ ! -e /etc/postfix/schleuder_domain_sqlite.cf ]] && cat <<EOF |$SUDO  tee -a /etc/postfix/schleuder_domain_sqlite.cf 
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
postmaster@lists.example.org    root@anotherdomain
abuse@lists.example.org         root@anotherdomain
MAILER-DAEMON@lists.example.org root@anotherdomain
root@lists.example.org          root@anotherdomain
BOF

$SUDO systemctl restart postfix
$SUDO mkdir -p /var/www/
cd /var/www/


echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Déploiement source schleuder-web ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

git clone https://0xacab.org/schleuder/schleuder-web/
$SUDO chown -R schleuder:root /var/www/schleuder-web
[[ ! -e /var/www/schleuder-web/tmp ]] && mkdir -p /var/www/schleuder-web/tmp
$SUDO chown -R schleuder:root /var/www/schleuder-web/tmp
$SUDO chmod 01755 /var/www/schleuder-web/tmp
cd schleuder-web
echo -e "${Red} installation de schleuder-web : ${NORMAL}"

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Install ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

#bundle install --without development
bundle config set --local without 'development'
bundle install

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Creation SECRET_KEY_BASE ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

export SECRET_KEY_BASE=$(bin/rails secret)

echo -e "${Red} SECRET_KEY_BASE=$SECRET_KEY_BASE${NORMAL}"


echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Creation SCHLEUDER_TLS_FINGERPRINT ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

export SCHLEUDER_TLS_FINGERPRINT=$($SUDO  schleuder cert fingerprint|cut -d" " -f4)


echo -e "${Red} 
SCHLEUDER_TLS_FINGERPRINT=$SCHLEUDER_TLS_FINGERPRINT${NORMAL}"
$SUDO systemctl restart schleuder-api-daemon.service


echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Creation SCHLEUDER_API_KEY ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

export SCHLEUDER_API_KEY=$($SUDO  schleuder new_api_key)
$SUDO sed -i "s/# shared:/shared:\n  api_key: ${SCHLEUDER_API_KEY}/g" ${SCHLEUDER_WEB}config/secrets.yml

echo -e "${Red} SCHLEUDER_API_KEY=$SCHLEUDER_API_KEY${NORMAL}"



$SUDO sed -i "s/  valid_api_keys:/  valid_api_keys:\n    - ${SCHLEUDER_API_KEY}/g" ${SCHLEUDER}schleuder.yml

grep ${SCHLEUDER_API_KEY} ${SCHLEUDER}schleuder.yml



echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Var schleuder-web ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "[Service]
SCHLEUDER_API_HOST=$SCHLEUDER_API_HOST
SCHLEUDER_API_PORT=$SCHLEUDER_API_PORT
SCHLEUDER_API_KEY=$SCHLEUDER_API_KEY
SCHLEUDER_TLS_FINGERPRINT=$SCHLEUDER_TLS_FINGERPRINT
SECRET_KEY_BASE=$SECRET_KEY_BASE
RAILS_ENV=production" | tee ${SCHLEUDER_WEB_VAR_DEFAULT}

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Service schleuder-web ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

echo -e "[Unit]
Description=Schleuder Web
After=local-fs.target network.target

[Service]
EnvironmentFile=${SCHLEUDER_WEB_VAR_DEFAULT}
WorkingDirectory=${SCHLEUDER_WEB}
User=schleuder
ExecStart=${SCHLEUDER_WEB}bin/bundle exec rails server  
[Install]
WantedBy=multi-user.target" | $SUDO  tee ${SCHLEUDER_WEB_SERVICE}

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Setup ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

bundle exec rake db:setup RAILS_ENV=production
echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Précompile ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

RAILS_ENV=production bundle exec rake assets:precompile

echo -e "${YELLOW} [==============================] ${NORMAL}"
echo -e "${YELLOW} Execution ${NORMAL}"
echo -e "${YELLOW} [==============================] ${NORMAL}"

$SUDO systemctl enable schleuder-web.service 
 
$SUDO systemctl start schleuder-web.service 

echo -e "${BLUE} Visit http://$(hostname -I|awk '{print $1}'):3000/${NORMAL}"
echo -e "${YELLOW} compte : root@localhost ${NORMAL}"
echo -e "${YELLOW} Password : slingit! ${NORMAL}"