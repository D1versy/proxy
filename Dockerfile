FROM python:3.12-slim

WORKDIR /app
COPY proxy_server.py .

EXPOSE 1111

CMD ["python3", "-u", "proxy_server.py"]
