#!/bin/bash
sudo systemctl stop nginx
sudo certbot renew > /var/log/renew_encryption.log
fuser -k 80/tcp
sudo systemctl start nginx