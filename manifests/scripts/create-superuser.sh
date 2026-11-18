#!/bin/sh
set -eu

./manage.py migrate --noinput

./manage.py shell -c "
from django.contrib.auth.models import User
import os

username = os.environ['SUPERUSER_USERNAME']
if User.objects.filter(username=username).exists():
    print(f'Superuser {username} already exists, skipping.')
else:
    User.objects.create_superuser(username, os.environ['SUPERUSER_EMAIL'], os.environ['SUPERUSER_PASSWORD'])
    print(f'Created superuser {username}.')
"
