#!/usr/bin/env bash
# Django project bootstrap script – June 2025

set -euo pipefail
trap 'deactivate 2>/dev/null || true' EXIT

###############################################################################
# Configuration –- set to RAW *folder* URL that contains Dockerfile etc.
###############################################################################
DOCKER_TEMPLATE_BASE="https://raw.githubusercontent.com/fatihemreakardere/django-project-creation-automation/main/docker"

###############################################################################
# Tiny colour helpers
###############################################################################
if [[ -t 1 ]]; then
  BOLD=$(tput bold) GREEN=$(tput setaf 2) YELLOW=$(tput setaf 3) RESET=$(tput sgr0)
else
  BOLD= GREEN= YELLOW= RESET=
fi

usage() { cat <<EOF
${BOLD}Django project bootstrapper${RESET}

Options:
  -n, --name NAME          Django package / folder name   (default: myproject)
  -y, --non-interactive    No prompts; rely on DJANGO_ADMIN_* env vars
  -g, --with-git           Initialise a Git repo (the .gitignore is written regardless)
  -h, --help               Show this help and exit

Environment (honoured when -y is used):
  DJANGO_ADMIN_USER        (default: admin)
  DJANGO_ADMIN_EMAIL       (default: \$DJANGO_ADMIN_USER@<project>.com)
  DJANGO_ADMIN_PASSWORD    (default: admin)
EOF
}

###############################################################################
main() {
  local PROJECT="myproject" NONINTERACTIVE=0 USE_GIT=0

  # --------------- flag parser ----------------------------------------------
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -n|--name)           PROJECT="$2"; shift 2 ;;
      -y|--non-interactive)NONINTERACTIVE=1; shift ;;
      -g|--with-git)       USE_GIT=1; shift ;;
      -h|--help)           usage; exit 0 ;;
      *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
  done

  # --------------- ensure Python --------------------------------------------
  if ! command -v python3 >/dev/null; then
    echo "${YELLOW}Python 3 not found – attempting to install…${RESET}"
    if   command -v apt-get >/dev/null; then
      sudo apt-get update -qq
      sudo apt-get install -y python3 python3-venv python3-pip build-essential libpq-dev
    elif command -v brew >/dev/null; then brew install python
    elif command -v dnf  >/dev/null; then
      sudo dnf install -y python3 python3-virtualenv python3-pip gcc postgresql-devel
    else
      echo "Package manager not recognised – install Python 3 manually."; exit 1
    fi
  fi

  # --------------- project root ---------------------------------------------
  mkdir -p "$PROJECT" && cd "$PROJECT"

  # --------------- .gitignore (always) --------------------------------------
  curl -fsSL https://raw.githubusercontent.com/github/gitignore/main/Python.gitignore \
       -o .gitignore
  echo -e "\n# Added by django_automation.sh\n.env\n.dockerignore" >> .gitignore
  echo "${GREEN}✔ .gitignore downloaded.${RESET}"

  # --------------- virtual env (.venv) --------------------------------------
  python3 -m venv .venv
  # shellcheck source=/dev/null
  source .venv/bin/activate 2>/dev/null || source .venv/Scripts/activate

  # --------------- requirements ---------------------------------------------
  cat > requirements.txt <<'REQ'
Django>=5.2,<6
djangorestframework>=3.15,<4
python-decouple>=3.8,<4
REQ
  python -m pip install -q --upgrade pip
  python -m pip install -q --no-cache-dir -r requirements.txt

  # --------------- Django project inside src/ -------------------------------
  mkdir -p src && cd src
  django-admin startproject "$PROJECT" .
  python manage.py migrate --noinput

  # --------------- .env ------------------------------------------------------
  SECRET_KEY=$(python - <<"PY"
import secrets,sys; print(secrets.token_urlsafe(50))
PY
)
  cat > ../.env <<ENV
DEBUG=True
SECRET_KEY=${SECRET_KEY}
ALLOWED_HOSTS=127.0.0.1,localhost
ENV
  echo "${GREEN}✔ .env generated.${RESET}"

  # patch settings.py for python-decouple
  sed -i "1i from decouple import config, Csv" "$PROJECT/settings.py"
  sed -i "s/^SECRET_KEY = .*/SECRET_KEY = config('SECRET_KEY')/"      "$PROJECT/settings.py"
  sed -i "s/^DEBUG = .*/DEBUG = config('DEBUG', cast=bool)/"          "$PROJECT/settings.py"
  sed -i "s/^ALLOWED_HOSTS.*/ALLOWED_HOSTS = config('ALLOWED_HOSTS', cast=Csv())/" \
         "$PROJECT/settings.py"
  cd ..

  # --------------- download Docker assets -----------------------------------
  for FILE in Dockerfile docker-compose.yml .dockerignore; do
    curl -fsSL "${DOCKER_TEMPLATE_BASE}/${FILE}" -o "${FILE}" \
      || { echo "${YELLOW}Failed to fetch ${FILE} – check template repo URL${RESET}"; exit 1; }
    echo "${GREEN}✔ ${FILE} downloaded.${RESET}"
  done

  # --------------- super user -----------------------------------------------
  if [[ $NONINTERACTIVE -eq 0 ]]; then
    read -rp "Admin username [admin]: "  ADMIN_USER;  ADMIN_USER=${ADMIN_USER:-admin}
    DEFAULT_EMAIL="${ADMIN_USER}@${PROJECT}.com"
    read -rp "Admin email [${DEFAULT_EMAIL}]: " ADMIN_EMAIL
    ADMIN_EMAIL=${ADMIN_EMAIL:-$DEFAULT_EMAIL}
    read -srp "Admin password [admin]: "         ADMIN_PASS; echo
    ADMIN_PASS=${ADMIN_PASS:-admin}
  else
    ADMIN_USER="${DJANGO_ADMIN_USER:-admin}"
    ADMIN_EMAIL="${DJANGO_ADMIN_EMAIL:-${ADMIN_USER}@${PROJECT}.com}"
    ADMIN_PASS="${DJANGO_ADMIN_PASSWORD:-admin}"
  fi

  cd src
  python manage.py createsuperuser --username "$ADMIN_USER" \
                                   --email    "$ADMIN_EMAIL" --noinput
  python manage.py shell - <<PY
from django.contrib.auth import get_user_model
u=get_user_model().objects.get(username="$ADMIN_USER")
u.set_password("$ADMIN_PASS"); u.save()
PY
  cd ..

  # --------------- optional Git init ----------------------------------------
  if [[ $USE_GIT -eq 1 ]]; then
    git init -q
    git add . && git commit -qm "Initial Django project (automated)"
    echo "${GREEN}✔ Git repository initialised.${RESET}"
  fi

  # --------------- done ------------------------------------------------------
  echo -e "\n${GREEN}🎉  Project ready.${RESET}"
  echo "Run locally:\n  ${BOLD}source .venv/bin/activate && python src/manage.py runserver${RESET}"
  echo -e "\nRun with Docker:\n  ${BOLD}docker compose up --build${RESET}"
}

main "$@"
