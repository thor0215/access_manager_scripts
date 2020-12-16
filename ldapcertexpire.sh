#!/bin/bash
# build 20191030
DOMAIN=example.com
ADMIN="notifications@example.com"
LDAPHOST=127.0.0.1
LDAPPORT=398
LDAPADMIN="cn=admin,o=novell"
LDAPPASSWORD="password"
LDAPCERTLOG=/tmp/LDAPCERTLOG.log
mkdir -p /tmp/


env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b o=novell -s sub -o ldif-wrap=no '(objectclass=nidsUserStoreReplica)' nidsPort nidsIPADDress nidsDisplayName 2>/dev/null |
grep -A2 nidsDisplayName > $LDAPCERTLOG
NUMOFLINES=`cat $LDAPCERTLOG | wc -l`
i=7
while [ $i -le $NUMOFLINES ]; do
    VAR1=`cat $LDAPCERTLOG | head -n$i | tail -n3`
    #echo "VAR1: $VAR1"
    NAME=`echo $VAR1 | awk '{print $2}'`
    IPADDRESS=`echo $VAR1 | awk '{print $4}'`
    PORT=`echo $VAR1 | awk '{print $6}'`
    EXPIRY=`echo | openssl s_client -connect $IPADDRESS:$PORT 2>/dev/null | openssl x509 -noout -dates | grep 'notAfter' | awk -F'=' '{print $2}' | { read notafter ; date -d "$notafter"  +'%Y%m%d%H%M'; }`
    #echo "EXPIRY: $EXPIRY"
    EXPIRY_YYYYMM=`echo $EXPIRY | cut -c-6`
    #echo "$NAME EXPIRY_YYYYMM: $EXPIRY_YYYYMM"

    CURRENT_YYYYMM=`date --date="+1 month" +'%Y%m'`
    #echo "CURRENT_YYYYMM: $CURRENT_YYYYMM"
    if [ $EXPIRY_YYYYMM -le $CURRENT_YYYYMM ]; then
        EXPIRY_DATE=`echo $EXPIRY | cut -c-8`
        EXPIRY_DAY=`echo $EXPIRY | cut -c7-8`
        EXPIRY_MTH=`echo $EXPIRY | cut -c5-6`
        EXPIRY_YEAR=`echo $EXPIRY | cut -c1-4`
        CURRENT_DATE=`date +%Y%m%d`
        CERTNAME=`echo $VAR1 | sed -e 's/nDSPKINotAfter: /~/' | cut -d~ -f1`
        if [ $EXPIRY_DATE == $CURRENT_DATE ]; then
            echo "Please contact $NAME server's administrator IMMEDIATELY to renew this server's LDAP Certificate. The certificate expired today $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" 
#            echo "Please contact $NAME server's administrator IMMEDIATELY to renew this server's LDAP Certificate. The certificate expired today $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" |
#            mail -r $HOSTNAME@$DOMAIN -s "Server Certificate will expire TODAY!! --> $NAME" $ADMIN
        else
            echo "Please contact $NAME server's administrator to renew the server's LDAP Certificate before it expires on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" 
#            echo "Please contact $NAME server's administrator to renew the server's LDAP Certificate before it expires on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" |
#            mail -r $HOSTNAME@$DOMAIN -s "LDAP Server Certificate will expire on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY) --> $NAME" $ADMIN
        fi
    fi
    ((i=$i+4))
done
