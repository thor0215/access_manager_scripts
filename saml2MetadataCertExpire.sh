#!/bin/bash
# build 20191030
DOMAIN=example.com
HOSTNAME=
ADMIN="notifications@example.com"
LDAPHOST="127.0.0.1"
LDAPPORT="389"
LDAPADMIN="cn=admin,o=novell"
LDAPPASSWORD="password"

# WHITELIST is a list of providers you want to ignore and 
# do not want to be notified about
# WHITELIST Format examples
#      WHITELIST="ProviderNAME1"
#      WHITELIST="ProviderNAME1|ProviderNAME2"
#      WHITELIST="ProviderNAME1|ProviderNAME2|ProviderNAME3"
#WHITELIST="ProviderNAME1|ProviderNAME2"

checkCertExpiration () {
    local CERT=$1
    local NAME=$2
    local CERTIFICATETYPE=$3
    local ENABLED=$4

    if [ "$ENABLED" == "TRUE" ] ; then
       getCertExpiryDate "$CERT" "$NAME" "$CERTIFICATETYPE"
       if [ "$getCertExpiryDate_result" != "0" ] ; then
       local EXPIRY=$getCertExpiryDate_result

    # Get expiration date in YYYYMM format
EXPIRY_YYYYMM=`echo $EXPIRY | cut -c-6`

    # Get current date in YYYYMM format
    CURRENT_YYYYMM=`date --date="+1 month" +'%Y%m'`
    
   if [ $EXPIRY_YYYYMM -le $CURRENT_YYYYMM ]; then
           EXPIRY_DATE=`echo $EXPIRY | cut -c-8`
           EXPIRY_DAY=`echo $EXPIRY | cut -c7-8`
           EXPIRY_MTH=`echo $EXPIRY | cut -c5-6`
           EXPIRY_YEAR=`echo $EXPIRY | cut -c1-4`
           CURRENT_DATE=`date +%Y%m%d`
           if [ $EXPIRY_DATE == $CURRENT_DATE ]; then
                echo "Please contact the server's administrator for Provider ID: $NAME IMMEDIATELY to renew the ${CERTIFICATETYPE^} Certificate. The certificate expired today $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)"
#                    echo "Please contact the server's administrator for Provider ID: $NAME IMMEDIATELY to renew the $CERTIFICATETYPE Certificate. The certificate expired today $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" | 
#                    mail -r $HOSTNAME@$DOMAIN -s "SAML Provider: $NAME ${CERTIFICATETYPE^} Certificate will expire TODAY!!" $ADMIN
           else
                echo "Please contact the server's administrator for Provider ID: $NAME to renew the ${CERTIFICATETYPE^} Certificate before it expires on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)"
#                    echo "Please contact the server's administrator for Provider ID: $NAME to renew the $CERTIFICATETYPE Certificate before it expires on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" | 
#                    mail -r $HOSTNAME@$DOMAIN -s "SAML Provider: $NAME ${CERTIFICATETYPE^} Certificate will expire on $EXPIRY_DAY-$EXPIRY_MTH-$EXPIRY_YEAR (DD-MM-YYYY)" $ADMIN
           fi
       fi
      fi
    fi
}

# Function to wrap base64 string for PEM Format
formatPEMCert () {
    local OLDCERT=$1
    local NEWCERT=""
    local LINE=true
    local WRAPSIZE=64
    unset formatPEMCert_result

    if (( ${#OLDCERT} > WRAPSIZE )); then 
        for ((k=0;k<${#OLDCERT}; k=k+WRAPSIZE)); do
            #vi vecho "$k"
            if $LINE  ; then
                NEWCERT="${NEWCERT}${OLDCERT:k:WRAPSIZE}"
                LINE=false
                #let k++
            else
                NEWCERT="${NEWCERT}
"
                NEWCERT="${NEWCERT}${OLDCERT:k:WRAPSIZE}"

            fi
        done
        # Add BEGIN/END CERTIFICATE lines
        formatPEMCert_result="-----BEGIN CERTIFICATE----- 
$NEWCERT
-----END CERTIFICATE-----"
    fi
}

getMetadata() {
     # 
     # env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b ${BASEDN} -s base -o ldif-wrap=no nidsTrustedProviderMetadata 2>/dev/null 
     # Parse the metadata attribute
     # grep 'nidsTrustedProviderMetadata:: ' 
     # Remove the attribute name to get just the value
     # sed 's/nidsTrustedProviderMetadata:: //' 
     # Decrypt base64 string
     # base64 -d - 
     # Remove ^M / Dos end of lines
     # sed -e 's/\r$//' 
     # Add new lines to KeyDescriptor and X509Certificate tags in metadata
     #sed -re "s/<([a-z0-9:\/]+)?KeyDescriptor>/<\1KeyDescriptor>\n/g" -e "s/<([a-z0-9:]+)?X509Certificate>([\n\r]*)/\n<\1X509Certificate>/g" -e "s/<([a-z0-9:\/]+)?X509Certificate>/\n<\1X509Certificate>/g" -e "s/<([a-z0-9:\/]+)?KeyDescriptor/\n<\1KeyDescriptor/g"`

     local BASEDN=$1
     unset getMetadata_result
     getMetadata_result=`env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b ${BASEDN} -s base -o ldif-wrap=no nidsTrustedProviderMetadata 2>/dev/null | grep 'nidsTrustedProviderMetadata:: ' | sed 's/nidsTrustedProviderMetadata:: //' | base64 -d - | sed -e 's/\r$//' | sed -re "s/<([a-z0-9:\/]+)?KeyDescriptor>/<\1KeyDescriptor>\n/g" -e "s/<([a-z0-9:]+)?X509Certificate>([\n\r]*)/\n<\1X509Certificate>/g" -e "s/<([a-z0-9:\/]+)?X509Certificate>/\n<\1X509Certificate>/g" -e "s/<([a-z0-9:\/]+)?KeyDescriptor/\n<\1KeyDescriptor/g"`
}

getCertFromMetadata () {
     local CERTTYPE="\"$1\""
     local METADATA=$2
     
     # echo METADATA
     # echo "$METADATA"
     # Grab the test that starts/ends with KeyDescriptor tag
     # sed -rn "/<([a-z0-9:]+)?KeyDescriptor use=$CERTTYPE>/,/<\/([a-z0-9:]+)?KeyDescriptor>/p" 
     # Grab the text that starts/ends with X509Certificate tag
     # sed -rn '/<([a-z0-9:]+)?X509Certificate>/,/<\/([a-z0-9:]+)?X509Certificate>/p' 
     # In case there are 2 signing or encryption certificates
     # Only pick the second one
     # Could be a bug if the first cert is the new certificate instead
     # of the old one
     # sed -rn '/<([a-z0-9:]+)?X509Certificate>/h;//!H;$!d;x;//p' 
     # Remote X509Certificate meta tags
     # sed -r -e 's/<\/([a-z0-9:]+)?X509Certificate>.*//' -e 's/.*<([a-z0-9:]+)?X509Certificate>//' 
     # Remove any blank lines within the base64
     # certificate string
     # sed -e '/^$/d' 
     # Remove any lines left with meta tags
     # grep -Ev '<[a-zA-Z0-9:\/]+>' 
     # Trim and newlines and spaces
     # tr -d '\n[:space:]'`
     CERT=`echo "$METADATA" | sed -rn "/<([a-z0-9:]+)?KeyDescriptor use=$CERTTYPE>/,/<\/([a-z0-9:]+)?KeyDescriptor>/p" |  sed -rn '/<([a-z0-9:]+)?X509Certificate>/,/<\/([a-z0-9:]+)?X509Certificate>/p' | sed -rn '/<([a-z0-9:]+)?X509Certificate>/h;//!H;$!d;x;//p' | sed -r -e 's/<\/([a-z0-9:]+)?X509Certificate>.*//' -e 's/.*<([a-z0-9:]+)?X509Certificate>//' | sed -e '/^$/d' | grep -Ev '<[a-zA-Z0-9:\/]+>' | tr -d '\n[:space:]'`

     # KeyDescriptor type is optional
     # If no use attribute assume it's a signing cert
     if [ "$CERT" == "" ] && [ "$CERTTYPE" == '"signing"' ] ; then 
     	CERT=`echo "$METADATA" | sed -rn "/<([a-z0-9:]+)?KeyDescriptor>/,/<\/([a-z0-9:]+)?KeyDescriptor>/p" |  sed -rn '/<([a-z0-9:]+)?X509Certificate>/,/<\/([a-z0-9:]+)?X509Certificate>/p' | sed -rn '/<([a-z0-9:]+)?X509Certificate>/h;//!H;$!d;x;//p' | sed -r -e 's/<\/([a-z0-9:]+)?X509Certificate>.*//' -e 's/.*<([a-z0-9:]+)?X509Certificate>//' | sed -e '/^$/d' | grep -Ev '<[a-zA-Z0-9:\/]+>' | tr -d '\n[:space:]'`
     fi
     
     # Get a proper PEM formatted cert
     formatPEMCert "$CERT"
     
     unset getCertFromMetadata_result
     getCertFromMetadata_result=$formatPEMCert_result
     # return formatted certificate
     #echo "$CERT"
}

getTrustedSPs () {
    # Find all configured SAML SPs
    # env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b o=novell -s sub -o ldif-wrap=no '(objectclass=nidsSaml2TrustedSP)'  dn 2>/dev/null 
    # Parse just the dn attribute 
    # grep 'dn: cn' 
    # Remove the attribute name to get just the value
    # sed 's/^dn: //'

    unset getTrustedSPs_result
    getTrustedSPs_result=`env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h ${LDAPHOST} -p ${LDAPPORT} -Z -x -D ${LDAPADMIN} -w ${LDAPPASSWORD} -b o=novell -s sub -o ldif-wrap=no '(objectclass=nidsSaml2TrustedSP)'  dn 2>/dev/null | grep 'dn: cn' | sed 's/^dn: //'`
}

getCertExpiryDate () {
    local CERT=$1
    local NAME=$2
    local CERTIFICATETYPE=$3
    unset getCertExpiryDate_result

    # Parse certificate using openssl to find the dates      
    CERTDETAILS=`echo "$CERT" | openssl x509 -noout -dates 2>/dev/null`
    # check exit code of openssl
    local status=$?
 
    # if exit code not 0 there was a problem with the certificate
    if test $status -eq 0; then
        local EXPIRY=`echo "$CERTDETAILS" | grep 'notAfter' | awk -F'=' '{print $2}' | { read notafter ; date -d "$notafter"  +'%Y%m%d%H%M'; }`
        if [ "$EXPIRY" != "" ] ; then
            # Return certificate expiration date
            getCertExpiryDate_result="$EXPIRY"
        fi
    else
        echo "Error: $NAME certificate is malformed"
        echo "$CERT" > /tmp/cert-${NAME}-${CERTIFICATETYPE}.pem && echo "Writing certificate to /tmp/cert-${NAME}-${CERTIFICATETYPE}.pem"
        getCertExpiryDate_result="0"
    fi
}

# Get the list of SAML SPs
getTrustedSPs
TRUSTEDSPS=$getTrustedSPs_result

COUNTER=0
# Loop through each defined SP
while IFS= read -r line; do
    # reset all variables
    unset PROVIDER 
    unset PROVIDERNAME
    unset PROVIDERENABLED
    unset SIGNINGCERT
    unset ENCRYPTIONCERT

    PROVIDER=`env LDAPTLS_CACERT=/var/opt/novell/eDirectory/data/SSCert.pem /opt/novell/eDirectory/bin/ldapsearch -h 127.0.0.1 -p 389 -Z -x -D cn=admin,o=novell -w kestrel -b "$line" -s base -o ldif-wrap=no nidsDisplayName nidsEnabled 2>/dev/null | grep -e 'nidsEnabled: ' -e 'nidsDisplayName: '` 
    PROVIDERNAME=`echo "$PROVIDER" | grep 'nidsDisplayName: ' | sed 's/nidsDisplayName: //'`
    PROVIDERENABLED=`echo "$PROVIDER" | grep 'nidsEnabled: ' | sed 's/nidsEnabled: //'`

    # Check if SAML SP is whitelisted and should be ignored
    if ! echo "$PROVIDERNAME" | grep -Eiq "$WHITELIST" ; then
        getMetadata "$line"
        METADATA=$getMetadata_result

        # Uncomment for debugging
        # echo "$METADATA" > /tmp/metadata-"$PROVIDERNAME".txt

        # Get Signing cert from metadata
        getCertFromMetadata "signing" "$METADATA"
        SIGNINGCERT=$getCertFromMetadata_result

        # Check if there was a certificate
        if (( `echo "$SIGNINGCERT" | wc -m` > 1 )) ; then
            # Check cert expiration
            checkCertExpiration "$SIGNINGCERT" $PROVIDERNAME "Signing" "$PROVIDERENABLED"
        fi

        # Get encryption cert from metadata
        getCertFromMetadata "encryption" "$METADATA"
        ENCRYPTIONCERT=$getCertFromMetadata_result

        # Check if there was a certificate
        if (( `echo "$ENCRYPTIONCERT" | wc -m` > 1 )) ; then
            checkCertExpiration "$ENCRYPTIONCERT" "$PROVIDERNAME" "Encryption" "$PROVIDERENABLED"
        fi

        # Uncomment to stop while loop after 1 cycle
        # or whatever number you set the test to
        # [ $COUNTER -gt 1 ] && exit

        let COUNTER=COUNTER+1
    fi
done <<< "$TRUSTEDSPS"

