#!/bin/bash

# Exit on error
set -e

# 📦 Install system dependencies
check_updates() {
    echo "🔍 Checking for updates and required packages..."
    sudo apt update
    sudo apt install -y python3-venv python3-pip curl
    echo "✅ System packages installed."
}

check_updates

# Prompt for project name
read -p "Enter your Django project name: " PROJECT_NAME

# Set up directories
BASE_DIR=$(pwd)
PROJECT_DIR="$BASE_DIR/$PROJECT_NAME"

mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Create virtual environment
python3 -m venv .venv

# Activate virtual environment
if [[ -f ".venv/bin/activate" ]]; then
    source .venv/bin/activate
elif [[ -f ".venv/Scripts/activate" ]]; then
    source .venv/Scripts/activate
else
    echo "❌ Could not find the virtual environment activation script."
    exit 1
fi

# Upgrade pip
pip install --upgrade pip

# Install Django, DRF
echo "📦 Installing Django, Django REST Framework"
pip install django djangorestframework

# Create Django project
django-admin startproject "$PROJECT_NAME" .

# Migrate DB
python3 manage.py migrate

# ✅ Download GitHub's Python .gitignore
echo "⬇️ Downloading Python .gitignore from GitHub..."
curl -s https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore -o .gitignore

## Init Git repo
read -p "Do you want to initialize a Git repository? (y/n): " INIT_GIT
if [[ "$INIT_GIT" == "y" ]]; then
    echo "📂 Initializing Git repository..."
    git init
    git add .
    git commit -m "Initial commit: Django project setup"
    echo "✅ Git repository initialized."
else
    echo "ℹ️ Skipping Git repository initialization."
fi

# 👤 Create Django admin user
read -p "Enter admin username: " ADMIN_USER
read -p "Enter admin email: " ADMIN_EMAIL
read -s -p "Enter admin password: " ADMIN_PASS
echo

# Create temporary Python script to create superuser
cat <<EOF > create_superuser.py
from django.contrib.auth import get_user_model

User = get_user_model()
username = "$ADMIN_USER"
email = "$ADMIN_EMAIL"
password = "$ADMIN_PASS"

if not User.objects.filter(username=username).exists():
    User.objects.create_superuser(username=username, email=email, password=password)
    print("✅ Superuser created successfully.")
else:
    print("ℹ️ Superuser already exists.")
EOF

python3 manage.py shell < create_superuser.py
rm create_superuser.py

# ✅ Project setup complete
echo "✅ Django project '$PROJECT_NAME' created successfully in $PROJECT_DIR"

# Prompt to run server
read -p "Do you want to run the development server? (y/n): " RUNSERVER
if [[ "$RUNSERVER" == "y" ]]; then
    python3 manage.py runserver
fi
