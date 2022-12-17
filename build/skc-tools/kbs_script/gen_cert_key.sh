OPENSSL=openssl
OUTDIR=./output
key_bits=3072

mkdir -p $OUTDIR

if [ ! -z "$1" ]; then
        key_bits=$1
        echo "Gen Cert & Key - Key bit size : $key_bits"
fi

rm $OUTDIR/*.cert
rm $OUTDIR/*.key
rm $OUTDIR/*.csr

CA_CONF_PATH=ca.cnf
CA_ROOT_CERT=$OUTDIR/root.cert
SERVER_CERT=$OUTDIR/server.cert
SERVER_KEY=$OUTDIR/server.key
SERVER_PKCS8_KEY=$OUTDIR/server_pkcs8.key

CN="RSA Root CA" $OPENSSL req -config ${CA_CONF_PATH} -x509 -nodes \
        -keyout ${CA_ROOT_CERT} -out ${CA_ROOT_CERT} -newkey rsa:$key_bits -days 3650

# EE RSA certificates: create request first
CN="localhost" $OPENSSL req -config ${CA_CONF_PATH} -nodes \
        -keyout ${SERVER_KEY} -out ${OUTDIR}/req.csr -newkey rsa:$key_bits

# Sign request: end entity extensions
$OPENSSL x509 -req -in ${OUTDIR}/req.csr -CA ${CA_ROOT_CERT} -days 3600 \
        -extfile ${CA_CONF_PATH} -extensions usr_cert -CAcreateserial >> ${SERVER_CERT}

$OPENSSL pkcs8 -topk8 -nocrypt -in ${SERVER_KEY} -out ${SERVER_PKCS8_KEY}

cat ${SERVER_PKCS8_KEY} | tr '\r\n' '@' | sed -e 's/@/\\n/g' > $OUTDIR/.key 
