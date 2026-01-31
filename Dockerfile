FROM linuxserver/chromium:latest

# Install additional dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Baresip SIP client and all modules
    baresip \
    baresip-core \
    # PulseAudio client library for baresip
    libpulse0 \
    # PulseAudio (full package for running our own server)
    pulseaudio \
    pulseaudio-utils \
    # Python for automation
    python3 \
    python3-pip \
    python3-venv \
    # Utilities for healthcheck and config
    curl \
    netcat-openbsd \
    gettext-base \
    procps \
    # Network tools for Baresip
    net-tools \
    && rm -rf /var/lib/apt/lists/* \
    # Debug: show where baresip modules are
    && find /usr/lib -name "*.so" -path "*/baresip/*" 2>/dev/null || true

# Install ALSA plugins to bridge to PulseAudio
RUN apt-get install -y --no-install-recommends libasound2-plugins

# Disable the base image's PulseAudio service - we run our own
# (prevents two PA instances from conflicting)
RUN if [ -d /etc/s6-overlay/s6-rc.d/svc-pulseaudio ]; then \
      echo '#!/bin/sh' > /etc/s6-overlay/s6-rc.d/svc-pulseaudio/run && \
      echo 'exec sleep infinity' >> /etc/s6-overlay/s6-rc.d/svc-pulseaudio/run && \
      chmod +x /etc/s6-overlay/s6-rc.d/svc-pulseaudio/run; \
    fi

# Install Python dependencies
COPY automation/requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir --break-system-packages -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Copy s6-overlay service definitions
COPY rootfs/ /

# Copy automation scripts
COPY automation/ /app/automation/

# Copy healthcheck script
COPY scripts/healthcheck.sh /scripts/healthcheck.sh

# Make scripts executable
RUN chmod +x /etc/s6-overlay/scripts/* \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-*/run \
    && chmod +x /etc/s6-overlay/s6-rc.d/svc-*/finish 2>/dev/null || true \
    && chmod +x /scripts/healthcheck.sh

# Environment variables
ENV CHROME_CLI="--no-sandbox --no-first-run --password-store=basic --start-maximized --test-type --remote-debugging-port=9229 --remote-debugging-address=0.0.0.0 --remote-allow-origins=* --use-fake-ui-for-media-stream --autoplay-policy=no-user-gesture-required --alsa-output-device=plug:default"
ENV CHROMIUM_CLI="${CHROME_CLI}"
ENV CHROME_DEBUGGING_PORT=9229
ENV PULSE_SERVER="unix:/alloc/pulse/socket"

# Pre-configure ALSA to use PulseAudio by default
RUN echo 'pcm.!default { type pulse }\nctl.!default { type pulse }' > /etc/asound.conf

# Expose ports
# 3000 - KasmVNC HTTP
# 3001 - KasmVNC HTTPS
# 5060 - SIP (UDP and TCP)
# 9229 - Chrome debugging
EXPOSE 3000 3001 5060/udp 5060/tcp 9229

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD /scripts/healthcheck.sh
