#!/bin/bash

## internalRecon.sh
## by Regen Peterson

while getopts f:t:h: flag
do
    case "${flag}" in
        f) scopeFile=${OPTARG};;
    esac
done

if [ -z $scopeFile ]
then 
    echo "Please include the scope file with './internalRecon.sh -f {FILENAME}'"

else 
    wd=$(pwd)
    echo "Creating recon directory at $wd/Recon"
    mkdir Recon

    echo "Using CrackMapExec to generate relay target list at $wd/Recon/relayTargets.txt"
    crackmapexec smb $scopeFile --gen-relay-list Recon/relayTargets.txt | tee Recon/cmeOut.txt

    echo "Extracting domain info from CME output and saving identified domainNames at $wd/Recon/domainNames.txt"
    cat Recon/cmeOut.txt | grep -i 'domain:' | awk -F'omain:' '{print $2}' | cut -d ')' -f 1 | sort -u > Recon/domainNames.txt

    echo "Identifying DC Hostnames via nslookup and saving at $wd/Recon/dcHostnames.txt"
    while read p; do
      nslookup -type=srv _ldap._tcp.dc._msdcs.$p | grep -i '.'$p | grep -vi 'failed:'| cut -d ' ' -f 6 | sed 's/.$//' >> Recon/dcHostnames.txt
    done < Recon/domainNames.txt

    echo "Extracting DC IP addresses with ping and saving to $wd/Recon/dcIpAddresses.txt"
    for ip in $(cat Recon/dcHostnames.txt); do ping $ip -c 1 | grep -i '64 bytes' | cut -d '(' -f 2 | cut -d ')' -f 1 >> Recon/dcIpAddresses.txt; done

    echo 'Checking DCs for LDAP Signing?: '
    crackmapexec ldap Recon/dcIpAddresses.txt -M ldap-signing
fi
