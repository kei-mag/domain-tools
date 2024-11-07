#!/usr/bin/sh

# This script notify current global IP to MyDNS.JP
# You can update your dynamic IP by running this script periodically with systemd timer.

# ++++++++++ Secrets ++++++++++
MasterID=mydnsXXXXXX
Password=yourpasswd
# +++++++++++++++++++++++++++++

IPV4_URL="https://ipv4.mydns.jp/login.html"
IPV6_URL="https://ipv6.mydns.jp/login.html"

echo "--------------- IPV4 ---------------"
curl --user $MasterID:$Password $IPV4_URL

echo "--------------- IPV6 ---------------"
curl --user $MasterID:$Password $IPV6_URL
