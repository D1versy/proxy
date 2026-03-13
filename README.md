# Forward Proxy Server

Simple HTTP/HTTPS forward proxy server in Python (stdlib only, no external dependencies).
Designed for use in local networks — e.g., to route traffic from another application
through a machine with a specific IP address.

---

## Features

- **HTTP proxy** — proxying GET, POST, PUT, DELETE, HEAD, OPTIONS, PATCH requests
- **HTTPS CONNECT tunnel** — transparent tunneling of TLS connections
- **Multithreading** — each incoming connection is handled in a separate thread
- **Configuration via environment variables**
- **Logging** — timestamp, method, target host, HTTP status
- **Graceful shutdown** — clean termination on `Ctrl+C` / `SIGTERM`
- **Docker-ready** — `Dockerfile` + `docker-compose.yml` included
- **Railway-ready** — `railway.toml` included for one-click deploy

---

## Quick Start

### Option 1: Docker (recommended)

```bash
# Clone the repository
git clone <repo-url> && cd proxy

# (optional) copy and edit .env
cp .env.example .env

# Start
docker compose up -d --build
```

The proxy will be available on port `1111` (or whatever is set in `PROXY_PORT`).

### Option 2: Run locally (no Docker)

```bash
python3 proxy_server.py
```

Or with a custom port:

```bash
PROXY_PORT=2222 python3 proxy_server.py
```

### Option 3: Windows Server (PowerShell)

On Windows without Docker — only Python 3 is required.

```powershell
# Start with default settings (port 1111)
.\start_proxy.ps1

# Custom port
.\start_proxy.ps1 -Port 2222

# Disable logging
.\start_proxy.ps1 -Port 1111 -NoLog
```

Or without the script:

```powershell
$env:PROXY_PORT = "1111"
python proxy_server.py
```

> **Note:** if Windows Firewall blocks incoming connections, add a rule:
> ```powershell
> New-NetFirewallRule -DisplayName "Forward Proxy" -Direction Inbound -Protocol TCP -LocalPort 1111 -Action Allow
> ```

### Option 4: Railway

1. Push this repo to GitHub
2. In Railway dashboard: **New Project → Deploy from GitHub repo**
3. Go to **Settings → Networking → TCP Proxy** and enable it
4. Set variable: `PROXY_PORT` = `${{PORT}}`
5. Use the provided TCP address in your client:

```env
INSTAGRAM_PROXY=http://region.proxy.rlwy.net:12345
```

---

## Configuration

All settings are controlled via environment variables:

| Variable     | Default   | Description                                    |
|-------------|-----------|------------------------------------------------|
| `PROXY_PORT` | `1111`    | Port the proxy listens on                      |
| `PROXY_BIND` | `0.0.0.0` | Bind address (network interface)              |
| `PROXY_LOG`  | `true`    | Log requests to stdout (`true`/`false`)        |

---

## Usage in a Client Project

### Step 1: Find the proxy server IP

On the machine running the proxy:

```bash
# Linux
hostname -I

# macOS
ipconfig getifaddr en0
```

Let's say the IP is `192.168.1.50`.

### Step 2: Configure the client project

In the `.env` file of your project, add:

```env
INSTAGRAM_PROXY=http://192.168.1.50:1111
```

### Step 3: Use in code (Python requests)

```python
import os
import requests

proxy_url = os.environ["INSTAGRAM_PROXY"]

session = requests.Session()
session.proxies = {
    "http": proxy_url,
    "https": proxy_url,
}

# HTTP request through proxy
response = session.get("http://httpbin.org/ip")
print(response.json())

# HTTPS request through proxy (CONNECT tunnel)
response = session.get("https://api.instagram.com/")
print(response.status_code)
```

---

## Client `.env` Examples

```env
# Proxy on another machine in the local network
INSTAGRAM_PROXY=http://192.168.1.50:1111

# Proxy on the same machine (for testing)
INSTAGRAM_PROXY=http://127.0.0.1:1111

# Proxy by hostname
INSTAGRAM_PROXY=http://my-proxy-server:1111

# Proxy on a custom port
INSTAGRAM_PROXY=http://192.168.1.50:2222
```

---

## Verifying the Proxy Works

### Using curl

```bash
# HTTP through proxy
curl -x http://localhost:1111 http://httpbin.org/ip

# HTTPS through proxy
curl -x http://localhost:1111 https://httpbin.org/ip
```

If everything works, both requests will return a JSON with the proxy server's IP address.

### Using Python

```python
import requests

proxies = {"http": "http://localhost:1111", "https": "http://localhost:1111"}
print(requests.get("https://httpbin.org/ip", proxies=proxies).json())
```

---

## Logs

When `PROXY_LOG=true` (default), stdout will show entries like:

```
2026-03-13 12:00:01  Proxy listening on 0.0.0.0:1111
2026-03-13 12:00:05  GET      http://httpbin.org/ip  200
2026-03-13 12:00:07  CONNECT  api.instagram.com:443  200
```

---

## Using as a Service in Another Docker Compose Project

If you want to add the proxy as a service in another project's `docker-compose.yml`:

```yaml
services:
  # ... your services ...

  proxy:
    build: ./proxy          # path to the directory with proxy_server.py and Dockerfile
    container_name: forward-proxy
    restart: unless-stopped
    ports:
      - "1111:1111"
    environment:
      - PROXY_PORT=1111
      - PROXY_LOG=true
```

From other containers in the same Docker network, the proxy is available at:

```env
INSTAGRAM_PROXY=http://proxy:1111
```

(where `proxy` is the service name in docker-compose)

---

## Network Access from Docker

If the proxy runs in Docker and the client is on the host machine:

```env
INSTAGRAM_PROXY=http://localhost:1111
```

If both the proxy and client are in Docker (same docker-compose network):

```env
INSTAGRAM_PROXY=http://forward-proxy:1111
# or by service name:
INSTAGRAM_PROXY=http://proxy:1111
```

If the proxy is in Docker and the client is on another machine in the network:

```env
# Use the IP of the host machine running Docker
INSTAGRAM_PROXY=http://192.168.1.50:1111
```

---

## Troubleshooting

### Proxy not responding

1. Check that the container is running: `docker compose ps`
2. Check logs: `docker compose logs proxy`
3. Verify the port is open: `curl http://localhost:1111` (expect a 400 error — that's normal, it means the proxy is working)

### Connection refused from another machine

1. Make sure the firewall is not blocking port `1111`
2. Check that `PROXY_BIND=0.0.0.0` (not `127.0.0.1`)
3. Test connectivity: `telnet <proxy-host> 1111`

### Timeouts

- Default connection timeout is 60 seconds
- If the target server doesn't respond within 60 seconds, the connection will be closed
- For long-lived connections, you can change `TIMEOUT` in `proxy_server.py`

### Docker: port already in use

```bash
# Find what's using the port
lsof -i :1111

# Use a different port
PROXY_PORT=2222 docker compose up -d --build
```

---

## Architecture

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

- **HTTP proxy**: the client sends a full URL in the request → the proxy parses the URL, connects to the origin server, forwards the request and response
- **HTTPS CONNECT**: the client sends `CONNECT host:443` → the proxy establishes a TCP connection to the target server → responds with `200` → starts a bidirectional relay (client and server communicate directly through the tunnel)
