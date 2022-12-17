server=$1
port=30445
ca_cert=resources/cms-ca.cert
tmp_cert=resources/tmp-ca.pem
	
curl -X GET -v "https://$server:$port/cms/v1/ca-certificates" -H 'Accept: application/x-pem-file' -k  > $tmp_cert
line=$(tail -n 1 $tmp_cert)
echo $line
if [[ $line != "-----END CERTIFICATE-----" ]]; then
        echo "Invalid CA file received"
        return
else
        cat $tmp_cert >> $ca_cert
fi
rm -rf $tmp_cert

