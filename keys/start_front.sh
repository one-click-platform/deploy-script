#!/bin/bash
su

docker run -v /home/ubuntu/env.js:/usr/share/nginx/html/static/env.js -p 81:80 -d $1

systemctl restart nginx.service

