#!/bin/sh
set -eu

./manage.py migrate --noinput

if output=$(./manage.py createsuperuser --noinput --username "$SUPERUSER_USERNAME" --email "$SUPERUSER_EMAIL" 2>&1); then
    echo "$output"
else
    case "$output" in
        *"already taken"*)
            echo "$output"
            ;;
        *)
            echo "$output" >&2
            exit 1
            ;;
    esac
fi
