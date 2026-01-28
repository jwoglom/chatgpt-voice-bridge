# ChatGPT Voice Bridge

A Docker container that bridges phone calls to ChatGPT's voice interface. Call a phone number, and ChatGPT answers.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Docker Container                              │
│                                                                  │
│  ┌──────────────┐    ┌─────────────────┐    ┌────────────────┐  │
│  │  PulseAudio  │───▶│   Baresip SIP   │───▶│  /alloc/       │  │
│  │  (audio hub) │    │   (phone)       │    │  call_active   │  │
│  └──────────────┘    └─────────────────┘    └───────┬────────┘  │
│         │                                           │           │
│         │            ┌─────────────────┐            │           │
│         └───────────▶│   Chromium +    │◀───────────┘           │
│                      │   KasmVNC       │                        │
│                      │   (browser)     │                        │
│                      └────────┬────────┘                        │
│                               │ CDP:9229                        │
│                      ┌────────▼────────┐                        │
│                      │   Playwright    │                        │
│                      │   (automation)  │                        │
│                      └─────────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

## Components

1. **PulseAudio** - Virtual audio routing between browser and SIP client
2. **Chromium + KasmVNC** - Browser for ChatGPT with web-based VNC access
3. **Baresip** - SIP client for handling phone calls
4. **Playwright Bot** - Automation that clicks ChatGPT voice buttons on call events

## Quick Start

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your SIP credentials:
   ```bash
   SIP_USER=your_sip_username
   SIP_PASS=your_sip_password
   SIP_SERVER=callcentric.com
   ```

3. Build and run:
   ```bash
   docker compose up -d
   ```

4. Access the web interface at `http://localhost:3000`

5. Log into ChatGPT in the browser

6. Call your SIP number - ChatGPT will answer!

## Configuration

### Required Environment Variables

| Variable | Description |
|----------|-------------|
| `SIP_USER` | SIP account username |
| `SIP_PASS` | SIP account password |
| `SIP_SERVER` | SIP server address (e.g., `callcentric.com`) |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SIP_TRANSPORT` | `tcp` | SIP transport protocol (`tcp`, `udp`, `tls`) |
| `SIP_OUTBOUND` | - | Outbound proxy (e.g., `sip:callcentric.com;transport=tcp`) |
| `SIP_REGINT` | `600` | Registration interval in seconds |
| `PUID` | `1000` | User ID for file permissions |
| `PGID` | `1000` | Group ID for file permissions |
| `TZ` | `Etc/UTC` | Container timezone |
| `CUSTOM_USER` | - | KasmVNC web username |
| `PASSWORD` | - | KasmVNC web password |

## Ports

| Port | Protocol | Description |
|------|----------|-------------|
| 3000 | HTTP | KasmVNC web interface |
| 3001 | HTTPS | KasmVNC web interface (SSL) |
| 5060 | UDP/TCP | SIP signaling |
| 9229 | TCP | Chrome debugging (optional) |

## Volumes

| Path | Description |
|------|-------------|
| `/config` | Persistent Chrome profile (cookies, login sessions) |

## Docker Run (Alternative)

If not using docker compose:

```bash
docker run -d \
  --name chatgpt-voice-bridge \
  --shm-size=1g \
  --security-opt seccomp=unconfined \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  -p 3000:3000 \
  -p 3001:3001 \
  -p 5060:5060/udp \
  -p 5060:5060/tcp \
  -v ./config:/config \
  -e SIP_USER=your_username \
  -e SIP_PASS=your_password \
  -e SIP_SERVER=callcentric.com \
  -e SIP_TRANSPORT=tcp \
  -e SIP_OUTBOUND="sip:callcentric.com;transport=tcp" \
  chatgpt-voice-bridge
```

## Health Check

The container includes health checks for all components:

- PulseAudio daemon and virtual sinks
- Chrome debugging port
- Baresip process
- Automation bot process
- KasmVNC web interface

Check health status:
```bash
docker inspect --format='{{.State.Health.Status}}' chatgpt-voice-bridge
```

## Troubleshooting

### View logs
```bash
docker compose logs -f
```

### Check individual service logs
```bash
# Baresip logs
docker exec chatgpt-voice-bridge cat /config/log/baresip/current

# Automation logs
docker exec chatgpt-voice-bridge cat /config/log/automation/current
```

### Verify PulseAudio sinks
```bash
docker exec chatgpt-voice-bridge pactl list short sinks
```

### Check SIP registration
Look for "registered" in baresip logs.

### Voice button not found
- Ensure you're logged into ChatGPT in the browser
- The ChatGPT UI may have changed - check the button selectors in `automation/bot.py`

## How It Works

1. **Incoming Call**: When someone calls your SIP number, Baresip auto-answers
2. **Call Detection**: Baresip creates `/alloc/call_active` file
3. **Voice Activation**: The Playwright bot detects the file and clicks "Start Voice" in ChatGPT
4. **Audio Routing**:
   - Caller audio → Baresip → VirtualMic sink → Chrome (as microphone)
   - ChatGPT audio → VirtualSpeaker sink → Baresip → Caller
5. **Call End**: When the call terminates, the bot clicks "End Voice"

## License

MIT
