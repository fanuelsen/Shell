if [ ${#} -ne 1 ]; then
  echo -e "Usage: \n\t$0 [VC_HOSTNAME]\n"
  exit 1
fi

NODE_IP=$1

DOWNLOAD_PATH=/tmp/cert.zip

curl -k -s "https://${NODE_IP}/certs/download.zip" -o ${DOWNLOAD_PATH}

unzip ${DOWNLOAD_PATH} -d /tmp > /dev/null 2>&1

for i in $(ls /tmp/certs/lin/*.0);
    do
      SOURCE_CERT=${i%%.*}
      cp "${i}" "/tmp/certs/${SOURCE_CERT##*/}.crt"
      echo "Importing to VC SSL Certificate to Certificate Store"
      cp "${i}" "/etc/pki/ca-trust/source/anchors/${SOURCE_CERT##*/}.crt"
      update-ca-trust extract
    done