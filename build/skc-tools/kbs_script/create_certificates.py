#!/usr/bin/env python

from cryptography import x509
from cryptography.hazmat import backends
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

import datetime
import sys
import ipaddress
import re
import socket

def create_rsa_private_key(key_size=2048, public_exponent=65537):
    private_key = rsa.generate_private_key(
        public_exponent=public_exponent,
        key_size=key_size,
        backend=backends.default_backend()
    )
    return private_key

def create_self_signed_certificate(subject_name, private_key, days_valid=365):
    subject = x509.Name([
        x509.NameAttribute(x509.NameOID.ORGANIZATION_NAME, u"Test, Inc."),
        x509.NameAttribute(x509.NameOID.COMMON_NAME, subject_name)
    ])
    certificate = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        subject
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).add_extension(
        x509.BasicConstraints(ca=True, path_length=None), critical=True
    ).not_valid_before(
        datetime.datetime.utcnow()
    ).not_valid_after(
        datetime.datetime.utcnow() + datetime.timedelta(days=days_valid)
    ).sign(private_key, hashes.SHA256(), backends.default_backend())

    return certificate

def create_certificate(subject_name,
                       private_key,
                       signing_certificate,
                       signing_key,
                       hostName="",
                       days_valid=365,
                       client_auth=False):
    subject = x509.Name([
        x509.NameAttribute(x509.NameOID.ORGANIZATION_NAME, u"Test, Inc."),
        x509.NameAttribute(x509.NameOID.COMMON_NAME, subject_name)
    ])
    builder = x509.CertificateBuilder().subject_name(
        subject
    ).issuer_name(
        signing_certificate.subject
    ).public_key(
        private_key.public_key()
    ).serial_number(
        x509.random_serial_number()
    ).not_valid_before(
        datetime.datetime.utcnow()
    ).not_valid_after(
        datetime.datetime.utcnow() + datetime.timedelta(days=days_valid)
    )

    if hostName != "":
        try: 
            builder = builder.add_extension(
                x509.SubjectAlternativeName([
                    x509.IPAddress(hostName),
                ]),
                critical=True
            )
        except TypeError:
            builder = builder.add_extension(
                x509.SubjectAlternativeName([
                    x509.DNSName(hostName),
                ]),
                critical=True
            )

    if client_auth:
        builder = builder.add_extension(
            x509.ExtendedKeyUsage([x509.ExtendedKeyUsageOID.CLIENT_AUTH]),
            critical=True
        )

    certificate = builder.sign(
        signing_key,
        hashes.SHA256(),
        backends.default_backend()
    )
    return certificate

def main():
    host_name = ""
    if len(sys.argv) == 2:
        validIP = "^((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])$"
    
        validHostName = "^((?!-)[A-Za-z0-9-]" + "{1,63}(?<!-)\\.)" + "+[A-Za-z]{2,6}"

        if(re.search(re.compile(validIP), sys.argv[1])):
            host_name = ipaddress.ip_address(u""+sys.argv[1])
        
        elif(re.search(re.compile(validHostName), sys.argv[1])):
            host_name = u""+sys.argv[1]
        
        else:
            raise ValueError("Invalid IP or DNS provided")
    
    elif len(sys.argv) == 1:
        print("Hostname argument is not provided. Proceeding with setting IP address to hostname.")
        IPAddress = socket.gethostbyname(socket.gethostname())
        host_name = ipaddress.ip_address(u""+IPAddress)
    
    else:
        raise IOError("Invalid arguments passed")

    print("Hostname set to ", host_name)

    root_key = create_rsa_private_key()
    root_certificate = create_self_signed_certificate(
        u"Root CA",
        root_key
    )

    server_key = create_rsa_private_key()
    server_certificate = create_certificate(
        u"Server Certificate",
        server_key,
        root_certificate,
        root_key,
        host_name,
    )

    client_key = create_rsa_private_key()
    client_certificate = create_certificate(
        u"Client Certificate",
        client_key,
        root_certificate,
        root_key,
        client_auth=True
    )

    with open("root_key.pem", "wb") as f:
        f.write(root_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ))
    with open("root_certificate.pem", "wb") as f:
        f.write(
            root_certificate.public_bytes(
                serialization.Encoding.PEM
            )
        )
    with open("server_key.pem", "wb") as f:
        f.write(server_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ))
    with open("server_certificate.pem", "wb") as f:
        f.write(
            server_certificate.public_bytes(
                serialization.Encoding.PEM
            )
        )
    with open("client_key.pem", "wb") as f:
        f.write(client_key.private_bytes(
            encoding=serialization.Encoding.PEM,
            format=serialization.PrivateFormat.PKCS8,
            encryption_algorithm=serialization.NoEncryption()
        ))
    with open("client_certificate.pem", "wb") as f:
        f.write(
            client_certificate.public_bytes(
                serialization.Encoding.PEM
            )
        )

if __name__ == '__main__':
    main()
