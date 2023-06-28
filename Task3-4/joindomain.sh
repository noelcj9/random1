#!/bin/bash

DOMAIN_FQDN_UPPERCASE=$(echo "${DOMAIN_FQDN}" | tr '[:lower:]' '[:upper:]')
DOMAIN_FQDN_LOWERCASE=$(echo "${DOMAIN_FQDN}" | tr '[:upper:]' '[:lower:]')

echo "'${PASSWORD}'"

# Update package lists
sudo apt-get update

# Install necessary packages
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y krb5-user samba sssd sssd-tools libnss-sss libpam-sss ntp ntpdate realmd adcli

# Update to let the VM contact domain
echo "nameserver ${PRIVATE_IP}" | sudo tee -a /etc/resolv.conf
echo "127.0.0.1 ${VM_NAME}.$DOMAIN_FQDN_LOWERCASE ${VM_NAME}" | sudo tee -a /etc/resolv.conf

# Update /etc/ntp.conf
sudo sed -i "/#Add one or more servers here/a server $DOMAIN_FQDN_LOWERCASE" /etc/ntp.conf

# Restart NTP service
sudo systemctl stop ntp
sudo ntpdate $DOMAIN_FQDN_LOWERCASE
sudo systemctl start ntp

# Discover the realm
realm discover $DOMAIN_FQDN_UPPERCASE

# Authenticate to Kerberos
echo "${PASSWORD}" | kinit -V ${DOMAIN_ADMIN}@$DOMAIN_FQDN_UPPERCASE

# Update /etc/krb5.conf
sudo sed -i '/\[libdefaults\]/a rdns=false' /etc/krb5.conf

# Join the realm (join computer to the domain)
echo "${PASSWORD}" | sudo realm join --verbose $DOMAIN_FQDN_LOWERCASE -U "${DOMAIN_ADMIN}@$DOMAIN_FQDN_UPPERCASE" --install=/

# Update /etc/sssd/sssd.conf
sudo sed -i 's/use_fully_qualified_names/#use_fully_qualified_names/' /etc/sssd/sssd.conf

# Restart SSSD service
sudo systemctl restart sssd

# Update /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Restart SSH service
sudo systemctl restart ssh

# Update /etc/pam.d/common-session
echo "session required pam_mkhomedir.so skel=/etc/skel/ umask=0022" | sudo tee -a /etc/pam.d/common-session

# Update /etc/sudoers file to allow domain admins the right to sudo
echo "%domain\ admins ALL=(ALL:ALL) ALL" | sudo tee -a /etc/sudoers