FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

COPY . .

# copy entrypoint and make it executable
COPY entrypoint.sh .
RUN chmod +x entrypoint.sh

# Work from src/ so manage.py is at CWD
WORKDIR /app/src

ENTRYPOINT ["../entrypoint.sh"]  

CMD ["gunicorn", "<project>.wsgi:application", "--bind", "0.0.0.0:8000"]