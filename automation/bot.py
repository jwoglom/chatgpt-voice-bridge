#!/usr/bin/env python3
"""
ChatGPT Voice Bridge - Playwright Automation Bot

Connects to Chrome via CDP and automates ChatGPT voice interactions
when a phone call is detected (via /alloc/call_active file).
"""

import asyncio
import os
import sys
from pathlib import Path
from playwright.async_api import async_playwright

CALL_TRIGGER_FILE = Path(os.getenv("CALL_ACTIVE_FILE", "/alloc/call_active"))
CDP_PORT = os.getenv("CHROME_DEBUGGING_PORT", "9229")
CDP_URL = f"http://localhost:{CDP_PORT}"


async def main():
    print(f"--- BOT STARTED | PID: {os.getpid()} ---")
    print(f"CDP URL: {CDP_URL}")
    print(f"Call trigger file: {CALL_TRIGGER_FILE}")

    async with async_playwright() as p:
        # 1. CONNECTION LOOP - Connect to Chrome via CDP
        browser = None
        while not browser:
            try:
                print(f"Connecting to Chrome at {CDP_URL}...")
                browser = await p.chromium.connect_over_cdp(CDP_URL)
                print(">>> SUCCESS: Connected to Chrome!")
            except Exception as e:
                print(f"Waiting for Chrome connection... ({e})")
                await asyncio.sleep(3)

        # 2. CONTEXT LOOP - Wait for browser context
        context = None
        while not context:
            if browser.contexts:
                context = browser.contexts[0]
                print("Attached to existing Browser Context.")
            else:
                print("Waiting for Browser Context (Open the VNC!)...")
                await asyncio.sleep(2)

        # 3. PAGE LOOP - Find or create ChatGPT tab
        page = None
        while not page:
            # Try to find an open ChatGPT tab
            for p_check in context.pages:
                try:
                    url = p_check.url
                    if "chatgpt.com" in url:
                        page = p_check
                        print(f"Attached to ChatGPT Tab: {url}")
                        break
                except Exception:
                    pass

            if not page:
                print("No ChatGPT tab found. Opening one...")
                page = await context.new_page()
                await page.goto("https://chatgpt.com")
                await asyncio.sleep(5)  # Let it load

        # 4. MAIN EVENT LOOP
        print(">>> BOT READY. Watching for incoming call trigger...")

        # Track if we are currently "In Call" to avoid spamming clicks
        is_in_call = False

        while True:
            # Check if the trigger file exists
            call_detected = CALL_TRIGGER_FILE.exists()

            if call_detected and not is_in_call:
                print(">>> INCOMING CALL DETECTED! Activating Voice Mode...")
                await page.bring_to_front()

                try:
                    # Look for the voice button
                    btn = page.locator('[aria-label="Start Voice"]')
                    if await btn.count() > 0:
                        if await btn.is_visible():
                            await btn.click()
                            print(">>> CLICKED! Talking to ChatGPT.")
                            is_in_call = True
                        else:
                            print("Error: Voice button found but not visible. (Login modal open?)")
                    else:
                        print("Error: Voice button NOT found. Are you logged in?")
                except Exception as e:
                    print(f"Error clicking voice button: {e}")

            elif not call_detected and is_in_call:
                print(">>> CALL ENDED. Stopping Voice Mode...")

                try:
                    # Click exit button to stop voice session
                    exit_btn = page.locator('button[aria-label="End Voice"]')
                    if await exit_btn.count() > 0:
                        await exit_btn.click()
                        print(">>> Voice session ended.")
                except Exception as e:
                    print(f"Error ending voice session: {e}")

                is_in_call = False

            await asyncio.sleep(1)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nBot stopped by user.")
        sys.exit(0)
