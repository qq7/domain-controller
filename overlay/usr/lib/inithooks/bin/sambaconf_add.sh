#!/bin/bash -e

while getopts d:r:u:p: option
    do
        case "${option}"
        in
        d) DOMAIN=${OPTARG};;
        r) REALM=${OPTARG};;
        u) ADMIN_USER=${OPTARG};;
        p) ADMIN_PASSWORD=${OPTARG};;
    esac
done

# stop Samba service(s) - in case it's already running
service samba stop >/dev/null || true
service samba-ad-dc stop >/dev/null || true

# just in case Samba4 has been set up Samba3 style
service smbd stop >/dev/null || true
service nmbd stop >/dev/null || true

# remove conf files
CONF=$(smbd -b | grep "CONFIGFILE" | cut -d: -f2)
rm -f $CONF
rm -f /etc/krb5.conf

# clean up *.tdb and *.ldb files (samba DBs)
DIRS=$(smbd -b | egrep "LOCKDIR|STATEDIR|CACHEDIR|PRIVATE_DIR" | cut -d: -f2)
for dir in $DIRS; do
    find $dir \( -name "*.tdb" -or -name "*.ldb" \) -delete || true
done

samba-tool domain provision --realm $REALM --domain $DOMAIN --adminpass $ADMIN_PASSWORD --server-role=dc --use-rfc2307 --option="dns forwarder = 8.8.8.8"

samba-tool user setexpiry $ADMIN_USER --noexpiry

samba-tool domain exportkeytab /etc/krb5.keytab

chown root:root /etc/krb5.keytab
chmod 600 /etc/krb5.keytab

cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
 
sed -i "s/^search .*/search $REALM/" /etc/resolvconf/resolv.conf.d/head
sed -i "s/^domain .*/domain $REALM/" /etc/resolvconf/resolv.conf.d/head

service samba-ad-dc start

sleep 5

echo $ADMIN_PASSWORD | kinit $ADMIN_USER

service samba-ad-dc start
