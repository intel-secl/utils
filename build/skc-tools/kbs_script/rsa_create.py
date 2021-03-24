import ssl
import os
import sys
import shutil
from kmip.pie.client import ProxyKmipClient, enums
from kmip.pie import objects
from kmip.pie import client
from kmip import enums
from subprocess import call

HOSTNAME_IP = 
CERT_PATH = 
KEY_PATH = 
CA_PATH = 

TEMP_DIRECTORY = 'temp'
CA_CONF_PATH='ca.cnf'
KEY_HEX_OUTPUT= TEMP_DIRECTORY + '/' + 'key_output.txt'
SERVER_CERT='server.crt'
SERVER_KEY= TEMP_DIRECTORY + '/' + 'server.pem'
CSR= TEMP_DIRECTORY + '/' +'server.csr'
RSA_DER = TEMP_DIRECTORY + '/' + 'rsa-key.der'

def CreateCertificate():
    
    # Generate the key in pem format
    call(['xxd','-r','-ps',KEY_HEX_OUTPUT,RSA_DER])
    call( [ 'openssl' , 'pkey' , '-in' , RSA_DER ,'-inform' ,'der' , '-out' , SERVER_KEY , '-outform' , 'pem'] )

    # Generate the csr
    call( [ 'openssl' , 'req' , '-new' , '-config' , CA_CONF_PATH, '-key', SERVER_KEY , '-out' , CSR ])

    # Generate the server certificate
    call( [ 'openssl' ,  'x509' , '-signkey' , SERVER_KEY, '-in' , CSR , '-req' , '-days', '365' , '-out' , SERVER_CERT ])

    shutil.rmtree(TEMP_DIRECTORY, ignore_errors=True)

    print("Server certificate : " + os.getcwd() + '/' + SERVER_CERT)


def AsymmetricKeyRSA():

    c = ProxyKmipClient(hostname=HOSTNAME_IP,port=5696,cert=CERT_PATH,key=KEY_PATH,ca=CA_PATH)
    print("Asymmetric Key Creation")
    with c:
        key_id = c.create_key_pair(
            enums.CryptographicAlgorithm.RSA,
            3072,
            public_usage_mask=[
                enums.CryptographicUsageMask.ENCRYPT
            ],
            private_usage_mask=[
                enums.CryptographicUsageMask.DECRYPT
            ]
        )  
        
        print("Private Key ID : " +key_id[1])

        current_directory = os.getcwd()
        temp_directory = os.path.join(current_directory,TEMP_DIRECTORY)
        if not os.path.exists(temp_directory):
            os.makedirs(temp_directory)

        orig_stdout = sys.stdout
        f = open(KEY_HEX_OUTPUT, 'w')
        sys.stdout = f
        print(c.get(key_id[1]))
        sys.stdout = orig_stdout
        f.close()


def main():
    AsymmetricKeyRSA()
    CreateCertificate()


if __name__ == "__main__":
    main()