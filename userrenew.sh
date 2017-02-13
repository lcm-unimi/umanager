#!/bin/bash
#userrenew.sh - add +3 years to user's shadowExpire
# by jp (2013)
MANAGER="cn=Manager"
BIND="dc=nanos8,dc=pcteor1"
TMPFILE="/tmp/umod.ldif"
#TMPFILE=tempfile.tmp

#FROM HERE...
clean(){
    stty echo
    rm $TMPFILE
    exit $1;
}

help(){
        echo "Usage: $0 <Username>"
        exit -1;
}

[ -z $1 ] && help

trap "clean -2" SIGINT SIGTERM

ldapsearch -x -A "uid=$1" > $TMPFILE

NENT=$(grep numEntries $TMPFILE | cut -d ':' -f 2)
 
[ -z $NENT ] || [ $NENT -ne 1 ] && \
echo User not found && clean -1;

# TO HERE, COPY-PASTED FROM USERMOD.SH; input checks and cleanup routine.

NEWYEAR="20`date +%y`"
NEWYEAR=$(($NEWYEAR+3))
MONTH=`date +%m`
DAY=`date +%d`

NEWSHADOW=$((`date --date="$NEWYEAR-$MONTH-$DAY" +%s`/ 86400)) #add +3 years to the shadowExpire

echo
echo La data di scadenza dell\'utente $1 verra\' modificata come segue:

DN=$(ldapsearch -x "uid=$1" shadowExpire \
	| grep dn: | cut -f2 -d':')
echo
{
	echo "dn: $DN"
	echo "changetype: modify"
	echo "replace: shadowExpire"
	echo "shadowExpire: $NEWSHADOW"
} | tee $TMPFILE
echo "nuova data: $NEWYEAR-$MONTH-$DAY"
echo
echo Apportare le modifiche? \(y/n\)

ANS=boh

until [[ $ANS == "y" ]]; do
	read ANS
	if [[ $ANS == "n" ]]; then clean 1; fi
done

EXITSTAT=49
while [[ $EXITSTAT -eq 49 ]]; do
	ldapmodify -x -D "$MANAGER,$BIND" -W -f $TMPFILE
	EXITSTAT=$?
done

#This line was inserted by eugen, to fix the discrepancy in the expiration date between ldap  
#and /etc/shadow (2015).
#$1 is the uid of ldap, corresponding to the username of /etc/shadow
chage -E $NEWSHADOW $1

echo Modifiche apportate. Nuova data di scadenza: "$NEWYEAR-$MONTH-$DAY".

echo -e "\n\nMandare mail di conferma rinnovo? (y/n)"

ANS=bho

until [[ $ANS == "y" ]]; do
	read ANS
	if [[ $ANS == "n" ]]; then clean 1; fi
done

TOMAIL=$(ldapsearch -x "uid=$1" | grep mail: | cut -f2 -d' ')


echo -e "To:<$TOMAIL>
From:"LCM Staff"  <staff@lcm.mi.infn.it>
Cc:<working@lcm.mi.infn.it>
Subject:"Rinnovo Account"
MIME-Version: 1.0
Content-Type: text/plain

Ciao, 

abbiamo rinnovato il tuo account.
La nuova data di scadenza e\`: "$NEWYEAR-$MONTH-$DAY".

Grazie per aver scelto LCM."\
      | sendmail -t -i	
        
clean $EXITSTAT
