FROM python:3.11-slim

WORKDIR /app
COPY app/requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r /app/requirements.txt

COPY app/ /app/
EXPOSE 5000
CMD ["python", "app.py"]
