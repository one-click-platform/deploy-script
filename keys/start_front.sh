#!/bin/bash
su

docker login docker.pkg.github.com --username xxxvik-xakerxxx --password 4ac0950429eec63b5c72306a43fc41090af6e720

docker pull docker.pkg.github.com/one-click-platform/web-client/web_eth:latest

docker run -v /home/ubuntu/env.js:/usr/share/nginx/html/static/env.js -p 81:80 -d docker.pkg.github.com/one-click-platform/web-client/web_eth

systemctl restart nginx.service

