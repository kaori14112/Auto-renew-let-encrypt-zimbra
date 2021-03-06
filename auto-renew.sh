#!/bin/bash

log() {
    if [[ "$log_facility" != "none" ]]; then
        logger -t "$log_tag" -p "${log_facility}.${1}" "$2"
    fi
}

information() {
    log "info" "$*"
}

error() {
    message "error" "$*"
    log "err" "$*"
}

restart_zimbra() (
    information "restart zimbra"

    sudo su - zimbra -c "zmcontrol restart" || {
        error "Restarting zimbra failed."
        return 5
    }
)
#EDIT YOUR DOMAIN AND CERTBOT LOCATION HERE
domain="mail.example.com"
certbot=/mnt/certbot/letsencrypt-auto

#NUMBER OF DAY REMAIN TO RENEW SSL
DAYS=30

log_tag="letsencrypt-zimbra"
log_facility="${log_facility:-local6}"

zimbra_cert=/opt/zimbra/ssl/zimbra/commercial/commercial.crt
letsencrypt_cert=/etc/letsencrypt/live/$domain/cert.pem
hash_orig=`sha1sum $letsencrypt_cert | awk '{print $1}'`

yum install git -y
if [[ $domain == "mail.example.com" ]];
then
	echo "You're not define your mail server domain, exiting..."
	exit 1
fi	

if [[ -d "/mnt/certbot/" ]];
then
	cp -R /mnt/certbot/ /mnt/certbot.bak/
	rm -rf /mnt/certbot
fi

git clone https://github.com/certbot/certbot.git /mnt

if openssl x509 -checkend $(( DAYS*24*60*60 )) -in "$zimbra_cert" &> /dev/null; then
	information "Certificate will be valid for next $DAYS days, exiting..."
	echo "Certificate will be valid for next $DAYS days, exiting..."
	exit 0
else
	information "Certificate will expire in $DAYS, certificate will be renewed."
	echo "Certificate will expire in $DAYS, certificate will be renewed."
	$certbot renew 
fi

hash_curr=`sha1sum $letsencrypt_cert | awk '{print $1}'`

echo "$hash_orig"
echo "$hash_curr"

if [[ "$hash_orig" == "$hash_curr" ]];
then
	echo "file not changed, exiting..."
	error "Certificate file NOT changed after running certbot! Exiting script"
	exit 0
else
	echo "cert files has changed, continue..."
fi

echo "-----BEGIN CERTIFICATE-----
MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/
MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMT
DkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVow
PzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQD
Ew5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEB
AN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4O
rz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEq
OLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9b
xiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw
7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaD
aeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNV
HQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqG
SIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69
ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXr
AvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZz
R8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5
JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYo
Ob8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ
-----END CERTIFICATE-----" >> /etc/letsencrypt/live/$domain/chain.pem

cp -a /opt/zimbra/ssl/letsencrypt /opt/zimbra/ssl/letsencrypt.$(date "+%Y%m%d")
rm -rf /opt/zimbra/ssl/letsencrypt/*

cp /etc/letsencrypt/live/$domain/* /opt/zimbra/ssl/letsencrypt/
chown -R zimbra:zimbra /opt/zimbra/ssl/letsencrypt/*

sudo su - zimbra -c "cd /opt/zimbra/ssl/letsencrypt && /opt/zimbra/bin/zmcertmgr verifycrt comm privkey.pem cert.pem chain.pem"

cp -a /opt/zimbra/ssl/zimbra /opt/zimbra/ssl/zimbra.$(date "+%Y%m%d")

cp /opt/zimbra/ssl/letsencrypt/privkey.pem /opt/zimbra/ssl/zimbra/commercial/commercial.key
chown -R zimbra:zimbra /opt/zimbra/ssl/zimbra/commercial/commercial.key
sudo su - zimbra -c  "cd /opt/zimbra/ssl/letsencrypt && /opt/zimbra/bin/zmcertmgr deploycrt comm cert.pem chain.pem"

restart_zimbra
