# Forward Proxy Server

Простой HTTP/HTTPS forward proxy сервер на Python (stdlib, без внешних зависимостей).
Предназначен для использования в локальной сети — например, чтобы направлять трафик
другого приложения через машину с нужным IP-адресом.

---

## Возможности

- **HTTP proxy** — проксирование GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH запросов
- **HTTPS CONNECT tunnel** — прозрачное туннелирование TLS-соединений
- **Многопоточность** — каждое входящее соединение обрабатывается в отдельном потоке
- **Конфигурация через переменные окружения**
- **Логирование** — timestamp, метод, целевой хост, HTTP-статус
- **Graceful shutdown** — корректное завершение по `Ctrl+C` / `SIGTERM`
- **Docker-ready** — `Dockerfile` + `docker-compose.yml` в комплекте

---

## Быстрый старт

### Вариант 1: Docker (рекомендуется)

```bash
# Клонировать репозиторий
git clone <repo-url> && cd proxy

# (опционально) скопировать и отредактировать .env
cp .env.example .env

# Запустить
docker compose up -d --build
```

Прокси будет доступен на порту `1111` (или на том, что указан в `PROXY_PORT`).

### Вариант 2: Локально (без Docker)

```bash
python3 proxy_server.py
```

Или с кастомным портом:

```bash
PROXY_PORT=2222 python3 proxy_server.py
```

### Вариант 3: Windows Server (PowerShell)

На Windows без Docker — достаточно установленного Python 3.

```powershell
# Запуск с настройками по умолчанию (порт 1111)
.\start_proxy.ps1

# Кастомный порт
.\start_proxy.ps1 -Port 2222

# Без логирования
.\start_proxy.ps1 -Port 1111 -NoLog
```

Или без скрипта, напрямую:

```powershell
$env:PROXY_PORT = "1111"
python proxy_server.py
```

> **Важно:** если Windows Firewall блокирует входящие подключения, нужно добавить правило:
> ```powershell
> New-NetFirewallRule -DisplayName "Forward Proxy" -Direction Inbound -Protocol TCP -LocalPort 1111 -Action Allow
> ```

---

## Конфигурация

Все настройки задаются через переменные окружения:

| Переменная   | По умолчанию | Описание                                      |
|-------------|-------------|-----------------------------------------------|
| `PROXY_PORT` | `1111`      | Порт, на котором слушает прокси               |
| `PROXY_BIND` | `0.0.0.0`  | Адрес привязки (интерфейс)                    |
| `PROXY_LOG`  | `true`      | Логирование запросов в stdout (`true`/`false`) |

---

## Использование в клиентском проекте

### Шаг 1: Узнать IP прокси-сервера

На машине, где запущен прокси:

```bash
# Linux
hostname -I

# macOS
ipconfig getifaddr en0
```

Допустим, IP — `192.168.1.50`.

### Шаг 2: Настроить клиентский проект

В `.env` файле вашего проекта добавьте:

```env
INSTAGRAM_PROXY=http://192.168.1.50:1111
```

### Шаг 3: Использовать в коде (Python requests)

```python
import os
import requests

proxy_url = os.environ["INSTAGRAM_PROXY"]

session = requests.Session()
session.proxies = {
    "http": proxy_url,
    "https": proxy_url,
}

# HTTP-запрос через прокси
response = session.get("http://httpbin.org/ip")
print(response.json())

# HTTPS-запрос через прокси (CONNECT tunnel)
response = session.get("https://api.instagram.com/")
print(response.status_code)
```

---

## Примеры `.env` для клиентского проекта

```env
# Прокси на другой машине в локальной сети
INSTAGRAM_PROXY=http://192.168.1.50:1111

# Прокси на той же машине (для тестирования)
INSTAGRAM_PROXY=http://127.0.0.1:1111

# Прокси по hostname
INSTAGRAM_PROXY=http://my-proxy-server:1111

# Прокси на нестандартном порту
INSTAGRAM_PROXY=http://192.168.1.50:2222
```

---

## Проверка работоспособности

### С помощью curl

```bash
# HTTP через прокси
curl -x http://localhost:1111 http://httpbin.org/ip

# HTTPS через прокси
curl -x http://localhost:1111 https://httpbin.org/ip
```

Если всё работает, оба запроса вернут JSON с IP-адресом прокси-сервера.

### С помощью Python

```python
import requests

proxies = {"http": "http://localhost:1111", "https": "http://localhost:1111"}
print(requests.get("https://httpbin.org/ip", proxies=proxies).json())
```

---

## Логи

При `PROXY_LOG=true` (по умолчанию) в stdout выводятся записи вида:

```
2026-03-13 12:00:01  Proxy listening on 0.0.0.0:1111
2026-03-13 12:00:05  GET      http://httpbin.org/ip  200
2026-03-13 12:00:07  CONNECT  api.instagram.com:443  200
```

---

## Docker Compose в составе другого проекта

Если вы хотите добавить прокси как сервис в `docker-compose.yml` другого проекта:

```yaml
services:
  # ... ваши сервисы ...

  proxy:
    build: ./proxy          # путь к директории с proxy_server.py и Dockerfile
    container_name: forward-proxy
    restart: unless-stopped
    ports:
      - "1111:1111"
    environment:
      - PROXY_PORT=1111
      - PROXY_LOG=true
```

Тогда из других контейнеров в той же Docker-сети прокси доступен по адресу:

```env
INSTAGRAM_PROXY=http://proxy:1111
```

(где `proxy` — имя сервиса в docker-compose)

---

## Сетевой доступ из Docker

Если прокси запущен в Docker, а клиент — на хост-машине:

```env
INSTAGRAM_PROXY=http://localhost:1111
```

Если и прокси, и клиент — в Docker (одна docker-compose сеть):

```env
INSTAGRAM_PROXY=http://forward-proxy:1111
# или по имени сервиса:
INSTAGRAM_PROXY=http://proxy:1111
```

Если прокси в Docker, а клиент — на другой машине в сети:

```env
# Используйте IP хост-машины, на которой запущен Docker
INSTAGRAM_PROXY=http://192.168.1.50:1111
```

---

## Troubleshooting

### Прокси не отвечает

1. Проверьте, что контейнер запущен: `docker compose ps`
2. Проверьте логи: `docker compose logs proxy`
3. Убедитесь, что порт открыт: `curl http://localhost:1111` (ожидается ошибка 400 — это нормально, значит прокси работает)

### Connection refused с другой машины

1. Убедитесь, что файрвол не блокирует порт `1111`
2. Проверьте, что `PROXY_BIND=0.0.0.0` (не `127.0.0.1`)
3. Проверьте доступность: `telnet <proxy-host> 1111`

### Таймауты

- По умолчанию таймаут соединений — 60 секунд
- Если целевой сервер не отвечает дольше 60 секунд, соединение будет закрыто
- Для длительных соединений можно изменить `TIMEOUT` в `proxy_server.py`

### Docker: порт уже занят

```bash
# Посмотреть, что занимает порт
lsof -i :1111

# Использовать другой порт
PROXY_PORT=2222 docker compose up -d --build
```

---

## Архитектура

```
┌──────────┐      HTTP GET       ┌─────────────┐      HTTP GET       ┌──────────────┐
│  Client  │ ──────────────────▶ │ Proxy Server │ ──────────────────▶ │ Origin Server│
│ (Python  │ ◀────────────────── │  (port 1111) │ ◀────────────────── │              │
│ requests)│      Response       └─────────────┘      Response       └──────────────┘
└──────────┘

┌──────────┐    CONNECT host:443  ┌─────────────┐    TCP connect      ┌──────────────┐
│  Client  │ ──────────────────▶  │ Proxy Server │ ──────────────────▶ │ Origin Server│
│          │    200 Established   │              │                     │   (TLS)      │
│          │ ◀──────────────────  │              │                     │              │
│          │ ◀═══ TLS tunnel ═══▶ │              │ ◀═══ TCP relay ═══▶ │              │
└──────────┘                      └─────────────┘                     └──────────────┘
```

- **HTTP proxy**: клиент отправляет полный URL в запросе → прокси разбирает URL, подключается к origin серверу, пересылает запрос и ответ
- **HTTPS CONNECT**: клиент отправляет `CONNECT host:443` → прокси устанавливает TCP-соединение с целевым сервером → отвечает `200` → запускает двунаправленный relay (клиент и сервер общаются напрямую через tunnel)
