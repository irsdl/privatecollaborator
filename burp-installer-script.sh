#!/bin/bash

# installing burp pro
VERSION="2024.3.1.4"
curl -o /tmp/burpinstall.sh -k "https://portswigger-cdn.net/burp/releases/download?product=pro&version=$VERSION&type=Linux"
chmod +x /tmp/burpinstall.sh
/tmp/burpinstall.sh -Djava.awt.headless=true
rm /tmp/burpinstall.sh

