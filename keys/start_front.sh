#!/bin/bash
su

docker login docker.pkg.github.com --username xxxvik-xakerxxx --password $1

docker pull docker.pkg.github.com/one-click-platform/web-client/web_eth:latest

docker run -v /home/ubuntu/env.js:/usr/share/nginx/html/static/env.js -p 81:80 -d docker.pkg.github.com/one-click-platform/web-client/web_eth

systemctl restart nginx.service

