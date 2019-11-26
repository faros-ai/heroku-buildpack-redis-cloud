#!/usr/bin/env bash
URLS=${REDIS_STUNNEL_URLS:-REDIS_CLOUD_URL}
n=1

mkdir -p /app/vendor/stunnel/var/run/stunnel/
echo "$STUNNEL_CERT" > /app/vendor/stunnel/stunnel.crt
echo "$STUNNEL_KEY" > /app/vendor/stunnel/stunnel.key
echo "$STUNNEL_CA" > /app/vendor/stunnel/stunnel_ca.crt
cat >> /app/vendor/stunnel/stunnel.conf << EOFEOF
foreground = yes

pid = /app/vendor/stunnel/stunnel4.pid

cert = /app/vendor/stunnel/stunnel.crt
key = /app/vendor/stunnel/stunnel.key
cafile = /app/vendor/stunnel/stunnel_ca.crt
verify = 2
delay = yes

socket = l:TCP_NODELAY=1
socket = r:TCP_NODELAY=1
options = NO_SSLv3
sslVersion = TLSv1.2

ciphers = ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS
renegotiation = no

TIMEOUTidle = 86400
debug = ${STUNNEL_LOGLEVEL:-notice}
EOFEOF

for URL in $URLS
do
  eval URL_VALUE=\$$URL
  PARTS=$(echo $URL_VALUE | perl -lne 'print "$1 $2 $3 $4 $5 $6 $7" if /^([^:]+):\/\/([^:]+):([^@]+)@(.*?):(.*?)(\/(.*?)(\\?.*))?$/')
  URI=( $PARTS )
  URI_SCHEME=${URI[0]}
  URI_USER=${URI[1]}
  URI_PASS=${URI[2]}
  URI_HOST=${URI[3]}
  URI_PORT=${URI[4]}

  echo "Setting ${URL}_STUNNEL config var"
  export ${URL}_STUNNEL=$URI_SCHEME://$URI_USER:$URI_PASS@127.0.0.1:637${n}

  cat >> /app/vendor/stunnel/stunnel.conf << EOFEOF
[$URL]
client = yes
accept = 127.0.0.1:637${n}
connect = $URI_HOST:$URI_PORT
retry = ${STUNNEL_CONNECTION_RETRY:-"no"}
EOFEOF

  let "n += 1"
done

chmod go-rwx /app/vendor/stunnel/*
