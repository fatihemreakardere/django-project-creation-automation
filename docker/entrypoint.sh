#!/bin/sh
set -e

# Run Django DB migrations on every container start
python manage.py makemigrations --noinput
python manage.py migrate --noinput
python manage.py collectstatic --noinput

exec "$@"
