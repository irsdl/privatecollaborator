# Burp Suite - Private Collaborator server

This is a modified fork by Soroush Dalili.

A script for installing private Burp Collaborator with Let's Encrypt SSL-certificate. Requires an Ubuntu virtual machine and public IP-address.

Works for example with Ubuntu 18.04/20.04/22.10 virtual machine and with following platforms:
- Amazon AWS EC2 VM (with or without Elastic IP).
- DigitalOcean VM (with or without Floating IP).

Please see the below blog post for usage instructions:

[https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/)

# Updates over the original repository
* Updated `install.sh` to make the setup easier and slightly safer:
  - Use `burp-installer-script.sh` to install Burp Suite Pro or create a symlink for `/usr/local/bin/BurpSuitePro` if it does not exists
  - Randomize `burp-metrics-path` for enhanced security.
  - Disable listening on port 53 by default in Ubuntu to set up Collaborator with no issues on port 53
* Changed polling ports
* Updated the README to reflect the changes and provide additional information.

## How to use:

1. Ensure DNS keys are in place, here is an example for `bc.yourdomain.fi` as the used Burp Collaborator subdomain (in Cloudflare, ensure proxy is off):
	```
	bc    IN    NS    ns1.yourdomain.fi.
	ns1.bc     IN      A       1.2.3.4
	```
2. Clone this repository.
3. Install Burp to /usr/local/bin/BurpSuitePro using `burp-installer-script.sh`.
4. Run `sudo ./install.sh yourdomain.fi your@email.fi` (the email is for Let's Encrypt expiry notifications).
5. You should now have Let's encrypt certificate for the domain and a private burp collaborator properly set up.
6. Configure your Burp Suite Professional to use it. Here is an example when custom ports for polling is used (Settings > Project > Collaborator):
	```
	Server location: bc.yourdomain.fi
	Polling location: bc.yourdomain.fi:8443
	```

The created `burpcollaborator` service is run in the end. It also ensures that it runs after a reboot. The certitficate renewal is also checked daily.

**Install commands based on the instructions above:**

```
git clone https://github.com/irsdl/privatecollaborator
cd privatecollaborator
./install.sh yourdomain.fi your@email.fi
```

**Troubleshooting**

* The `Service busy; retry later` error from the certbot:
	certificates need to be recreated. Run the `./install.sh yourdomain.fi your@email.fi` file again.

### Important note:

When utilizing custom ports (8443 and 8080) for polling on your Collaborator server, it is possible to restrict access to these ports to specific IP addresses. This enhances security by keeping your Collaborator server private. However, configuring such restrictions can be challenging if the server must accommodate connections from various environments or dynamically changing IP addresses. This is especially the case when the collaborator server needs to be used by various consultants using differnet locations or network requirements.

As stated in [the blog post](https://teamrot.fi/self-hosted-burp-collaborator-with-custom-domain/), be sure to firewall the ports 8443 and 8080 properly to allow connections only from your own Burp Suite computer IP address. Otherwise everyone in the internet can use your collaborator server!
