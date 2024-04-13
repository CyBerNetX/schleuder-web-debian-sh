#!/usr/bin/bash
SUDO=/usr/bin/sudo
export START="$(date +%s)"

export VARTMP=/tmp/schleuderwebuninstall.tmp
LOGDIR="./log"
LOG="$LOGDIR/Remove_schleuder-web_$(date +%F_%H%M%S).log"
[ "$DEBUG" == 'true' ] && set -x

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
# cat $VARTMP
sleep 5


$SUDO VARTMP=$VARTMP -i -u $UTILISATEUR  <<"END_SWUSC"
. $VARTMP
cd $SCHLEUDER_WEB

bundle list | ruby -e 'ARGF.readlines[1..-1].each {|l| g = l.split(" ");  puts "Removing #{g[1]}"; `gem uninstall --force #{g[1]} -v #{g[2].gsub(/\(|\)/, "")}`; }'
END_SWUSC

