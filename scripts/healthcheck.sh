#!/bin/bash
# Health check script for ChatGPT Voice Bridge container
# Checks all 4 components: PulseAudio, Chromium, Baresip, Automation

set -e

CDP_PORT="${CHROME_DEBUGGING_PORT:-9229}"

# Check 1: PulseAudio is running
if ! pactl info >/dev/null 2>&1; then
    echo "UNHEALTHY: PulseAudio not responding"
    exit 1
fi

# Check 2: Virtual audio sinks exist
if ! pactl list short sinks | grep -q "VirtualMic"; then
    echo "UNHEALTHY: VirtualMic sink not found"
    exit 1
fi

if ! pactl list short sinks | grep -q "VirtualSpeaker"; then
    echo "UNHEALTHY: VirtualSpeaker sink not found"
    exit 1
fi

# Check 3: Chrome debugging port is accessible
if ! curl -sf "http://localhost:${CDP_PORT}/json/version" >/dev/null; then
    echo "UNHEALTHY: Chrome CDP port ${CDP_PORT} not responding"
    exit 1
fi

# Check 4: Baresip process is running
if ! pgrep -x baresip >/dev/null; then
    echo "UNHEALTHY: Baresip process not running"
    exit 1
fi

# Check 5: Automation bot is running
if ! pgrep -f "python3.*bot.py" >/dev/null; then
    echo "UNHEALTHY: Automation bot not running"
    exit 1
fi

# Check 6: KasmVNC web interface is accessible
if ! curl -sf "http://localhost:3000/" >/dev/null; then
    echo "UNHEALTHY: KasmVNC web interface not responding"
    exit 1
fi

echo "HEALTHY: All services running"
exit 0
