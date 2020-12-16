#!/bin/bash
FROMEMAIL="from@company.local"
#TOEMAIL="admin@company.local user2@company.local"
TOEMAIL="admin@company.local"
LDAPHOST="server.local"
LDAPPORT="389"
LDAPADMIN="cn=admin,o=local"
LDAPPASSWORD="P@ssw0rd"
Organization='o=local'
CERTLOG=/tmp/CERTLOG.log
mkdir -p /tmp/
env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b "$Organization" 'objectClass=nDSPKIKeyMaterial' nDSPKINotAfter |
grep -B1 '^nDSPKINotAfter' > $CERTLOG
NUMOFLINES=`cat $CERTLOG | wc -l`
i=2
while [ $i -le $NUMOFLINES ]; do
VAR1=`cat $CERTLOG | head -n$i | tail -n2`
#echo "VAR1: $VAR1"
EXPIRY=`echo $VAR1 | sed -e 's/nDSPKINotAfter: /~/' | cut -d~ -f2`
#echo "EXPIRY: $EXPIRY"
EXPIRY_YYYYMM=`echo $EXPIRY | cut -c-6`
#echo "EXPIRY_YYYYMM: $EXPIRY_YYYYMM"
#CURRENT_YYYYMM=`date +%Y%m`
## month +1
CURRENT_YYYYMM=`date --date="+1 month" +'%Y%m'`
#echo "CURRENT_YYYYMM: $CURRENT_YYYYMM"
if [ $EXPIRY_YYYYMM -le $CURRENT_YYYYMM ]; then
               EXPIRY_DATE=`echo $EXPIRY | cut -c-8`
               EXPIRY_DAY=`echo $EXPIRY | cut -c7-8`
               EXPIRY_MTH=`echo $EXPIRY | cut -c5-6`
               EXPIRY_YEAR=`echo $EXPIRY | cut -c1-4`
               CURRENT_DATE=`date +%Y%m%d`
               CERTNAME=`echo $VAR1 | sed -e 's/nDSPKINotAfter: /~/' | cut -d~ -f1 | sed -e 's/dn: //' -e 's/ $//'`
               if [ $EXPIRY_DATE == $CURRENT_DATE ]; then
                              echo "Please use iManager to repair the Certificate IMMEDIATELY $CERTNAME from $FROMEMAIL"
# Uncomment to enable emails
#                              echo "Please use iManager to repair the Certificate IMMEDIATELY" | 
#                              mail -r $FROMEMAIL -s "Server Certificate will expire TODAY!! --> $CERTNAME" $TOEMAIL
               else        
                              echo "Please use iManager to repair the Certificate $CERTNAME from $FROMEMAIL will expire on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY) --> $CERTNAME to $TOEMAIL"
# Uncomment to enable emails
#                              echo "Please use iManager to repair the Certificate" |
#                              mail -r $FROMEMAIL -s "Server Certificate will expire on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY) --> $CERTNAME" $TOEMAIL
               fi   
fi   
((i=$i+3))
done

rm -f ${CERTLOG}
