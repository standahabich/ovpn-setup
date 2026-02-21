:local clientSecrets {
    {"name"="klient1"; "pass"="Heslo1"};
    {"name"="klient2"; "pass"="Heslo2"};
    {"name"="klient3"; "pass"="Heslo3"};
}
:local serverName "example.cz"
:local serverAddress "ovpn.example.cz"
:local clientPassphrase "example1234"
:local ipLocalAddress "10.8.3.1"
:local ipPoolRange "10.8.3.2-10.8.3.199"

:local prefixName "ovpn"
:local caNameCert  ("$prefixName_$serverName_ca")
:local svNameCert  ("$prefixName_$serverName_server")
:local clNameCert  ("$prefixName_$serverName_client_")
:local profileName ("$prefixName_$serverName_profile")
:local ipPoolName  ("$prefixName_$serverName_pool")

:if ([:len [/system script job find where script=[:jobname]]] > 1) do={
    /log error "OVPN: script instance already running"
    :error "OVPN: script instance already running"
}

/log error "OVPN: start generation, version 1.00"

# CERT FIX NAME - imported key
/certificate set [find where common-name=$caNameCert] name=$caNameCert trusted=yes
/certificate set [find where common-name=$svNameCert] name=$svNameCert trusted=yes

# CA
/log warning "OVPN: #### CA ####"
:if ([:len [/certificate/find where name=$caNameCert]] > 0) do={
    /log info ("OVPN: CERT $caNameCert is exists – skiping")
    :if ([/certificate get $caNameCert private-key] != true) do={
    /log error "OVPN: CA certificate exists but has NO private key – import .p12 required"
        :error "OVPN: Missing CA private key"
    }
} else={
    /log info ("OVPN: ADD CERT CA: $caNameCert")
    /certificate/add name=$caNameCert common-name=$caNameCert days-valid=4350 key-usage=crl-sign,key-cert-sign
    /log info ("OVPN: SIGN: $caNameCert")
    /certificate/sign $caNameCert
    :delay 250ms
}

# SERVER
/log warning "OVPN: #### SERVER ####"

:if ([:len [/certificate/find where name=$svNameCert]] > 0) do={
    /log info ("OVPN: CERT $svNameCert is exists – skiping")
    :if ([/certificate get $svNameCert private-key] != true) do={
        /log error "OVPN: SERVER certificate exists but has NO private key – import .p12 required"
        :error "OVPN: Missing SERVER private key"
    }
} else={
    /log info ("OVPN: ADD CERT: $svNameCert")
    /certificate/add name=$svNameCert common-name=$svNameCert days-valid=4350 key-usage=tls-server
    /log info ("OVPN: SIGN: $svNameCert")
    :delay 250ms
    /certificate/sign $svNameCert ca=$caNameCert
    :delay 250ms
    /certificate/set $svNameCert trusted=yes
}

# CERT EXPORT FOR BACKUP
/certificate/export-certificate $svNameCert type=pkcs12 export-passphrase=$clientPassphrase
/certificate/export-certificate $caNameCert type=pkcs12 export-passphrase=$clientPassphrase
:delay 250ms

:if ([:len [/ip/pool/find where name=$ipPoolName]] > 0) do={
    /log info ("OVPN: EDIT SERVER POOL: $ipPoolName")
    /ip/pool/set $ipPoolName ranges=$ipPoolRange
} else={
    /log info ("OVPN: ADD SERVER POOL: $ipPoolName")
    /ip/pool/add name=$ipPoolName ranges=$ipPoolRange
}

:if ([:len [/ppp/profile/find where name=$profileName]] > 0) do={
    /log info ("OVPN: EDIT SERVER PROFILE: $profileName")
    /ppp/profile/set $profileName local-address=$ipLocalAddress remote-address=$ipPoolName
} else={
    /log info ("OVPN: ADD SERVER PROFILE: $profileName")
    /ppp/profile/add name=$profileName local-address=$ipLocalAddress remote-address=$ipPoolName
}

:if ([:len [/interface/ovpn-server/server/find where name=$serverName]] > 0) do={
    /log info ("OVPN: EDIT SERVER: $serverName")
    /interface/ovpn-server/server/set [/interface/ovpn-server/server/find where name=$serverName] certificate=$svNameCert require-client-certificate=yes cipher=aes256-cbc disabled=no default-profile=$profileName
} else={
    /log info ("OVPN: ADD SERVER: $serverName")
    /interface/ovpn-server/server/add name=$serverName certificate=$svNameCert require-client-certificate=yes cipher=aes256-cbc disabled=no default-profile=$profileName
}

# CLIENT
/log warning "OVPN: #### CLIENT ####"
/file/remove [find type=".ovpn file"]
/certificate/export-certificate $caNameCert type=pem
:delay 250ms

:foreach c in=$clientSecrets do={

    :local user (:$c->"name")
    :local pass (:$c->"pass")

    # KONTROLA EXISTENCE CERTIFIKÁTU
    :if ([:len [/certificate/find where name=($clNameCert . $user)]] > 0) do={
        /log info ("OVPN: CERT $user is exists – skiping")
    } else={
        /log info ("OVPN: ADD CERT: $user")
        # 1) vytvoření klientského certifikátu
        /certificate add name=($clNameCert . $user) common-name=($clNameCert . $user) key-size=2048 days-valid=4350 key-usage=tls-client

        /log info ("OVPN: SIGN: $user")
        # 2) podepsání certifikátu CA
        /certificate sign ($clNameCert . $user) ca=$caNameCert

        :delay 250ms
    }

    :if ([:len [/ppp secret/find where name=$user]] > 0) do={
        /log info ("OVPN: SET PPP SECRET: $user")
        /ppp secret set $user password="$pass" service=ovpn profile=$profileName
    } else={
        /log info ("OVPN: ADD PPP SECRET: $user")
        /ppp secret add name="$user" password="$pass" service=ovpn profile=$profileName
    }

    /log info ("OVPN: EXPORT: $user")
    # 5) export .ovpn souboru
    /certificate/export-certificate ($clNameCert . $user) type=pem export-passphrase=$clientPassphrase
    :delay 250ms

    /interface/ovpn-server/server/export-client-configuration \
        server=$serverName \
        server-address=$serverAddress \
        ca-certificate=("cert_export_" . $caNameCert . ".crt") \
        client-certificate=("cert_export_" . $clNameCert . $user . ".crt") \
        client-cert-key=("cert_export_" . $clNameCert . $user . ".key")

    :delay 250ms

    /file/set [/file/get [find where name~"client.*\\.ovpn"] name] name=($serverAddress . "_" . $user . ".ovpn")

    /file/remove ("cert_export_" . $clNameCert . $user . ".crt")
    /file/remove ("cert_export_" . $clNameCert . $user . ".key")
}
/file/remove "cert_export_$caNameCert.crt"

/log warning "OVPN: done"
