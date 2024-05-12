# Updates Over the Original Repository
* Added `burp-installer-script.sh` to install Burp Suite with updated default paths for more intuitive setup.
* Updated `install.sh` to:
  - Randomize `burp-metrics-path` for enhanced security.
  - Disable listening on port 53 by default in Ubuntu to set up Collaborator with no issues on port 53
* Changed polling ports to HTTP(S) defaults.
* Updated the README to reflect these changes and provide additional usage information.

# Burp Suite - Private collaborator server

A script for installing private Burp Collaborator with Let's Encrypt SSL-certificate. Requires an Ubuntu virtual machine and public IP-address.

Works for example with Ubuntu 18.04/20.04/22.10 virtual machine and with following platforms:
- Amazon AWS EC2 VM (with or without Elastic IP).
- DigitalOcean VM (with or without Floating IP).

Please see the below blog post for usage instructions:

[https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/)

## TL;DR:

1. Clone this repository.
2. Install Burp to /usr/local/bin/BurpSuitePro using `burp-installer-script.sh`.
2.1. If you already have a BurpSuitePro installed, create a symlink `ln -s "/somepath/BurpSuitePro" "/usr/local/bin/BurpSuitePro"`
3. Run `sudo ./install.sh yourdomain.fi your@email.fi` (the email is for Let's Encrypt expiry notifications).
4. You should now have Let's encrypt certificate for the domain and a private burp collaborator properly set up.
5. Start the collaborator with `sudo service burpcollaborator start`.
6. Configure your Burp Suite Professional to use it.
7. ????
8. Profit.

### Important note:

As stated in [the blog post](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/), be sure to firewall the ports 9443 and 9090 properly to allow connections only from your own Burp Suite computer IP address. Otherwise everyone in the internet can use your collaborator server!
