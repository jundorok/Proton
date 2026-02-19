#!/usr/bin/env python3
"""
Proton Calendar CLI via Playwright web automation.

Usage:
  python3 calendar.py list [--from YYYY-MM-DD] [--to YYYY-MM-DD]
  python3 calendar.py get --id <event-id>
  python3 calendar.py create --title TEXT --date YYYY-MM-DD [--time HH:MM]
                              [--duration MINUTES] [--description TEXT]
                              [--location TEXT] [--all-day]
  python3 calendar.py update --id <event-id> [--title TEXT] [--date YYYY-MM-DD]
                              [--time HH:MM] [--duration MINUTES]
                              [--description TEXT] [--location TEXT]
  python3 calendar.py delete --id <event-id>

Credentials are read from environment variables:
  PROTON_ACCOUNT  — your Proton email address
  PROTON_PASSWORD — your Proton account password

Session is cached at ~/.proton-calendar-session.json to avoid repeated logins.
Output: JSON on stdout, errors on stderr.
"""

import argparse
import json
import os
import sys
import time
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout
except ImportError:
    print(
        json.dumps({"error": "playwright not installed. Run: pip install playwright && playwright install chromium"}),
        file=sys.stderr,
    )
    sys.exit(1)

SESSION_FILE = Path.home() / ".proton-calendar-session.json"
CALENDAR_URL = "https://calendar.proton.me"
LOGIN_URL = "https://account.proton.me/login"
TIMEOUT = 30_000  # 30s


def get_credentials():
    account = os.environ.get("PROTON_ACCOUNT")
    password = os.environ.get("PROTON_PASSWORD")
    if not account or not password:
        print(
            json.dumps({"error": "PROTON_ACCOUNT and PROTON_PASSWORD environment variables must be set"}),
            file=sys.stderr,
        )
        sys.exit(1)
    return account, password


def save_session(context):
    storage = context.storage_state()
    SESSION_FILE.write_text(json.dumps(storage))


def load_session():
    if SESSION_FILE.exists():
        return json.loads(SESSION_FILE.read_text())
    return None


def is_logged_in(page):
    try:
        page.wait_for_url("**/calendar.proton.me/**", timeout=5_000)
        return True
    except PWTimeout:
        return False


def login(page, account, password):
    page.goto(LOGIN_URL, wait_until="networkidle")

    # Enter email
    page.fill('input[id="username"]', account)
    page.click('button[type="submit"]')
    page.wait_for_timeout(1000)

    # Enter password
    page.fill('input[id="password"]', password)
    page.click('button[type="submit"]')

    # Wait for redirect to app
    try:
        page.wait_for_url("**proton.me/**", timeout=TIMEOUT)
    except PWTimeout:
        print(
            json.dumps({"error": "Login timed out. Check credentials or 2FA requirement."}),
            file=sys.stderr,
        )
        sys.exit(1)

    # Navigate to calendar
    page.goto(CALENDAR_URL, wait_until="networkidle")


def get_browser_page(playwright):
    account, password = get_credentials()
    browser = playwright.chromium.launch(headless=True)
    session = load_session()

    if session:
        context = browser.new_context(storage_state=session)
        page = context.new_page()
        page.goto(CALENDAR_URL, wait_until="networkidle")
        if not is_logged_in(page):
            # Session expired — re-login
            context.close()
            context = browser.new_context()
            page = context.new_page()
            login(page, account, password)
            save_session(context)
    else:
        context = browser.new_context()
        page = context.new_page()
        login(page, account, password)
        save_session(context)

    return browser, context, page


def parse_event_from_dom(event_el):
    """Extract event data from a calendar event DOM element."""
    try:
        event_id = event_el.get_attribute("data-event-id") or event_el.get_attribute("data-id") or ""
        title = event_el.inner_text().strip().split("\n")[0] if event_el else ""
        return {"id": event_id, "title": title}
    except Exception:
        return {}


def cmd_list(args):
    with sync_playwright() as p:
        browser, context, page = get_browser_page(p)
        try:
            # Navigate to the date range if specified
            if args.date_from:
                page.goto(f"{CALENDAR_URL}?start={args.date_from}", wait_until="networkidle")
            else:
                page.goto(CALENDAR_URL, wait_until="networkidle")

            page.wait_for_timeout(2000)

            # Intercept the calendar API response via network
            events = []

            def handle_response(response):
                if "/api/calendar/v1/" in response.url and "events" in response.url:
                    try:
                        data = response.json()
                        if isinstance(data, dict) and "Events" in data:
                            for ev in data["Events"]:
                                shared_data = {}
                                for part in ev.get("SharedEvents", []):
                                    shared_data.update(part.get("Data", {}))
                                events.append({
                                    "id": ev.get("ID", ""),
                                    "calendarId": ev.get("CalendarID", ""),
                                    "title": shared_data.get("Summary", "(no title)"),
                                    "date": shared_data.get("RRuleString", "") or ev.get("StartTime", ""),
                                    "location": shared_data.get("Location", ""),
                                    "description": shared_data.get("Description", ""),
                                    "attendees": [
                                        {"email": a.get("Email", ""), "name": a.get("DisplayName", "")}
                                        for a in shared_data.get("Attendees", [])
                                    ],
                                    "visibility": "PRIVATE" if ev.get("Permissions", 0) == 0 else "PUBLIC",
                                })
                    except Exception:
                        pass

            page.on("response", handle_response)

            # Trigger a navigation to load events
            page.reload(wait_until="networkidle")
            page.wait_for_timeout(3000)

            print(json.dumps(events, indent=2, ensure_ascii=False))
        finally:
            save_session(context)
            browser.close()


def cmd_get(args):
    if not args.id:
        print(json.dumps({"error": "--id is required"}), file=sys.stderr)
        sys.exit(1)

    with sync_playwright() as p:
        browser, context, page = get_browser_page(p)
        try:
            event_data = {}

            def handle_response(response):
                if f"/api/calendar/v1/" in response.url and args.id in response.url:
                    try:
                        data = response.json()
                        event = data.get("Event", data)
                        shared_data = {}
                        for part in event.get("SharedEvents", []):
                            shared_data.update(part.get("Data", {}))
                        event_data.update({
                            "id": event.get("ID", args.id),
                            "title": shared_data.get("Summary", "(no title)"),
                            "date": event.get("StartTime", ""),
                            "location": shared_data.get("Location", ""),
                            "description": shared_data.get("Description", ""),
                            "attendees": [
                                {"email": a.get("Email", ""), "name": a.get("DisplayName", "")}
                                for a in shared_data.get("Attendees", [])
                            ],
                        })
                    except Exception:
                        pass

            page.on("response", handle_response)
            page.goto(f"{CALENDAR_URL}/event/{args.id}", wait_until="networkidle")
            page.wait_for_timeout(2000)

            if not event_data:
                event_data = {"id": args.id, "error": "Event not found or could not be parsed"}

            print(json.dumps(event_data, indent=2, ensure_ascii=False))
        finally:
            save_session(context)
            browser.close()


def cmd_create(args):
    if not args.title or not args.date:
        print(json.dumps({"error": "--title and --date are required"}), file=sys.stderr)
        sys.exit(1)

    with sync_playwright() as p:
        browser, context, page = get_browser_page(p)
        try:
            page.goto(CALENDAR_URL, wait_until="networkidle")
            page.wait_for_timeout(1500)

            # Click "New event" button
            new_event_btn = page.locator('button[data-testid="create-event"], button:has-text("New event"), [aria-label="New event"]').first
            new_event_btn.click()
            page.wait_for_timeout(1000)

            # Fill title
            title_input = page.locator('input[id="event-title-input"], input[placeholder*="title" i], input[aria-label*="title" i]').first
            title_input.fill(args.title)

            # Fill date
            date_input = page.locator('input[data-testid="start-date"], input[aria-label*="start date" i]').first
            date_input.fill(args.date)
            page.keyboard.press("Tab")

            # Fill time if provided and not all-day
            if args.time and not args.all_day:
                time_input = page.locator('input[data-testid="start-time"], input[aria-label*="start time" i]').first
                time_input.fill(args.time)
                page.keyboard.press("Tab")

            # Fill description if provided
            if args.description:
                desc_input = page.locator('textarea[data-testid="event-description"], textarea[aria-label*="description" i]').first
                desc_input.fill(args.description)

            # Fill location if provided
            if args.location:
                loc_input = page.locator('input[data-testid="event-location"], input[aria-label*="location" i]').first
                loc_input.fill(args.location)

            # Save the event
            save_btn = page.locator('button[data-testid="save-event"], button:has-text("Save"), button[type="submit"]').first
            save_btn.click()
            page.wait_for_timeout(2000)

            print(json.dumps({
                "status": "created",
                "title": args.title,
                "date": args.date,
                "time": args.time or "all-day" if args.all_day else args.time,
                "location": args.location or "",
            }))
        finally:
            save_session(context)
            browser.close()


def cmd_update(args):
    if not args.id:
        print(json.dumps({"error": "--id is required"}), file=sys.stderr)
        sys.exit(1)

    with sync_playwright() as p:
        browser, context, page = get_browser_page(p)
        try:
            # Open the event
            page.goto(f"{CALENDAR_URL}/event/{args.id}", wait_until="networkidle")
            page.wait_for_timeout(1500)

            # Click edit button
            edit_btn = page.locator('button:has-text("Edit"), button[aria-label*="edit" i]').first
            edit_btn.click()
            page.wait_for_timeout(1000)

            if args.title:
                title_input = page.locator('input[id="event-title-input"], input[aria-label*="title" i]').first
                title_input.fill(args.title)

            if args.date:
                date_input = page.locator('input[data-testid="start-date"], input[aria-label*="start date" i]').first
                date_input.fill(args.date)
                page.keyboard.press("Tab")

            if args.time:
                time_input = page.locator('input[data-testid="start-time"], input[aria-label*="start time" i]').first
                time_input.fill(args.time)
                page.keyboard.press("Tab")

            if args.description:
                desc_input = page.locator('textarea[data-testid="event-description"], textarea[aria-label*="description" i]').first
                desc_input.fill(args.description)

            if args.location:
                loc_input = page.locator('input[data-testid="event-location"], input[aria-label*="location" i]').first
                loc_input.fill(args.location)

            save_btn = page.locator('button[data-testid="save-event"], button:has-text("Save"), button[type="submit"]').first
            save_btn.click()
            page.wait_for_timeout(2000)

            print(json.dumps({"status": "updated", "id": args.id}))
        finally:
            save_session(context)
            browser.close()


def cmd_delete(args):
    if not args.id:
        print(json.dumps({"error": "--id is required"}), file=sys.stderr)
        sys.exit(1)

    with sync_playwright() as p:
        browser, context, page = get_browser_page(p)
        try:
            page.goto(f"{CALENDAR_URL}/event/{args.id}", wait_until="networkidle")
            page.wait_for_timeout(1500)

            # Click delete/trash button
            delete_btn = page.locator('button[aria-label*="delete" i], button[aria-label*="remove" i], button:has-text("Delete")').first
            delete_btn.click()
            page.wait_for_timeout(500)

            # Confirm deletion dialog if present
            confirm_btn = page.locator('button:has-text("Delete"), button:has-text("Confirm"), button:has-text("Yes")').first
            if confirm_btn.is_visible():
                confirm_btn.click()
                page.wait_for_timeout(1500)

            print(json.dumps({"status": "deleted", "id": args.id}))
        finally:
            save_session(context)
            browser.close()


def main():
    parser = argparse.ArgumentParser(description="Proton Calendar CLI via Playwright")
    sub = parser.add_subparsers(dest="command", required=True)

    # list
    p_list = sub.add_parser("list", help="List calendar events")
    p_list.add_argument("--from", dest="date_from", metavar="YYYY-MM-DD")
    p_list.add_argument("--to", dest="date_to", metavar="YYYY-MM-DD")

    # get
    p_get = sub.add_parser("get", help="Get a single event")
    p_get.add_argument("--id", required=True)

    # create
    p_create = sub.add_parser("create", help="Create a new event")
    p_create.add_argument("--title", required=True)
    p_create.add_argument("--date", required=True, metavar="YYYY-MM-DD")
    p_create.add_argument("--time", metavar="HH:MM")
    p_create.add_argument("--duration", type=int, metavar="MINUTES")
    p_create.add_argument("--description")
    p_create.add_argument("--location")
    p_create.add_argument("--all-day", action="store_true")

    # update
    p_update = sub.add_parser("update", help="Update an existing event")
    p_update.add_argument("--id", required=True)
    p_update.add_argument("--title")
    p_update.add_argument("--date", metavar="YYYY-MM-DD")
    p_update.add_argument("--time", metavar="HH:MM")
    p_update.add_argument("--duration", type=int, metavar="MINUTES")
    p_update.add_argument("--description")
    p_update.add_argument("--location")

    # delete
    p_delete = sub.add_parser("delete", help="Delete an event")
    p_delete.add_argument("--id", required=True)

    args = parser.parse_args()

    commands = {
        "list": cmd_list,
        "get": cmd_get,
        "create": cmd_create,
        "update": cmd_update,
        "delete": cmd_delete,
    }

    try:
        commands[args.command](args)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
