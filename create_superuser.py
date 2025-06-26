import os
from django.contrib.auth import get_user_model

User = get_user_model()

username = os.getenv("DJANGO_SUPERUSER_USERNAME")
email = os.getenv("DJANGO_SUPERUSER_EMAIL")
password = os.getenv("DJANGO_SUPERUSER_PASSWORD")
project_name = os.getenv("DJANGO_PROJECT_NAME")

if len(username) == 0:
    username = "admin"
if len(email) == 0:
    email = f"admin@{project_name}.com"
if len(password) == 0:
    password = "admin"

if not username or not password:
    print("❌ Username or password environment variables not set.")
    exit(1)

if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username=username, email=email, password=password)
    print("✅ Superuser created successfully.")
else:
    print("ℹ️ Superuser already exists.")