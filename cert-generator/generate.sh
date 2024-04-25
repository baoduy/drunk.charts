# Private key
openssl req -x509 -nodes -days 36500 -newkey rsa:2048 -keyout dev.local.key -out dev.local.crt -config openssl.cnf

# kubectl create secret tls my-tls-secret --key dev.local.key --cert dev.local.crt