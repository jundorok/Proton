#!/usr/bin/env python3
"""
Proton Mail CLI wrapper using proton-python-client.

Usage:
  python3 mail.py list [--folder inbox] [--limit 10]
  python3 mail.py read --id <message-id>
  python3 mail.py send --to <email> --subject <text> --body <text>
  python3 mail.py reply --id <message-id> --body <text>
  python3 mail.py search --query <text>
  python3 mail.py delete --id <message-id>
  python3 mail.py folders

Credentials are read from environment variables:
  PROTON_ACCOUNT  — your Proton email address
  PROTON_PASSWORD — your Proton account password

Output: JSON on stdout, errors on stderr.
"""

import argparse
import json
import os
import sys

try:
    from proton.client import ProtonClient
except ImportError:
    print(
        json.dumps({"error": "proton-client not installed. Run: pip install proton-client"}),
        file=sys.stderr,
    )
    sys.exit(1)


FOLDER_IDS = {
    "inbox": 0,
    "all": 5,
    "sent": 2,
    "drafts": 1,
    "trash": 3,
    "spam": 4,
    "archive": 6,
}


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


def connect():
    account, password = get_credentials()
    client = ProtonClient()
    client.authenticate(account, password)
    return client


def cmd_list(args):
    client = connect()
    folder = args.folder.lower()
    label_id = FOLDER_IDS.get(folder, 0)
    messages = client.get_messages(label_id=label_id, limit=args.limit)
    result = []
    for msg in messages:
        result.append({
            "id": msg.get("ID"),
            "subject": msg.get("Subject", "(no subject)"),
            "sender": msg.get("Sender", {}).get("Address", ""),
            "date": msg.get("Time"),
            "read": msg.get("Unread", 1) == 0,
            "size": msg.get("Size"),
        })
    print(json.dumps(result, indent=2, ensure_ascii=False))


def cmd_read(args):
    if not args.id:
        print(json.dumps({"error": "--id is required"}), file=sys.stderr)
        sys.exit(1)
    client = connect()
    msg = client.get_message(args.id)
    body = msg.get("Body", "")
    result = {
        "id": msg.get("ID"),
        "subject": msg.get("Subject", "(no subject)"),
        "sender": msg.get("Sender", {}).get("Address", ""),
        "to": [r.get("Address") for r in msg.get("ToList", [])],
        "date": msg.get("Time"),
        "body": body,
        "attachments": [
            {"name": a.get("Name"), "size": a.get("Size"), "mime": a.get("MIMEType")}
            for a in msg.get("Attachments", [])
        ],
    }
    print(json.dumps(result, indent=2, ensure_ascii=False))


def cmd_send(args):
    if not args.to or not args.subject or not args.body:
        print(json.dumps({"error": "--to, --subject, and --body are required"}), file=sys.stderr)
        sys.exit(1)
    client = connect()
    client.send_message(
        to=args.to,
        subject=args.subject,
        body=args.body,
    )
    print(json.dumps({"status": "sent", "to": args.to, "subject": args.subject}))


def cmd_reply(args):
    if not args.id or not args.body:
        print(json.dumps({"error": "--id and --body are required"}), file=sys.stderr)
        sys.exit(1)
    client = connect()
    original = client.get_message(args.id)
    sender_addr = original.get("Sender", {}).get("Address", "")
    subject = original.get("Subject", "")
    if not subject.lower().startswith("re:"):
        subject = f"Re: {subject}"
    client.send_message(
        to=sender_addr,
        subject=subject,
        body=args.body,
        reply_to=args.id,
    )
    print(json.dumps({"status": "replied", "to": sender_addr, "subject": subject}))


def cmd_search(args):
    if not args.query:
        print(json.dumps({"error": "--query is required"}), file=sys.stderr)
        sys.exit(1)
    client = connect()
    messages = client.search_messages(query=args.query, limit=args.limit)
    result = []
    for msg in messages:
        result.append({
            "id": msg.get("ID"),
            "subject": msg.get("Subject", "(no subject)"),
            "sender": msg.get("Sender", {}).get("Address", ""),
            "date": msg.get("Time"),
        })
    print(json.dumps(result, indent=2, ensure_ascii=False))


def cmd_delete(args):
    if not args.id:
        print(json.dumps({"error": "--id is required"}), file=sys.stderr)
        sys.exit(1)
    client = connect()
    client.delete_message(args.id)
    print(json.dumps({"status": "deleted", "id": args.id}))


def cmd_folders(args):
    client = connect()
    labels = client.get_labels()
    result = []
    for label in labels:
        result.append({
            "id": label.get("ID"),
            "name": label.get("Name"),
            "type": label.get("Type"),
        })
    print(json.dumps(result, indent=2, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description="Proton Mail CLI via proton-python-client")
    sub = parser.add_subparsers(dest="command", required=True)

    # list
    p_list = sub.add_parser("list", help="List messages in a folder")
    p_list.add_argument("--folder", default="inbox")
    p_list.add_argument("--limit", type=int, default=10)

    # read
    p_read = sub.add_parser("read", help="Read a single message")
    p_read.add_argument("--id", dest="id")

    # send
    p_send = sub.add_parser("send", help="Send a new email")
    p_send.add_argument("--to")
    p_send.add_argument("--subject")
    p_send.add_argument("--body")

    # reply
    p_reply = sub.add_parser("reply", help="Reply to a message")
    p_reply.add_argument("--id", dest="id")
    p_reply.add_argument("--body")

    # search
    p_search = sub.add_parser("search", help="Search messages")
    p_search.add_argument("--query")
    p_search.add_argument("--limit", type=int, default=10)

    # delete
    p_delete = sub.add_parser("delete", help="Delete a message")
    p_delete.add_argument("--id", dest="id")

    # folders
    sub.add_parser("folders", help="List all folders/labels")

    args = parser.parse_args()

    commands = {
        "list": cmd_list,
        "read": cmd_read,
        "send": cmd_send,
        "reply": cmd_reply,
        "search": cmd_search,
        "delete": cmd_delete,
        "folders": cmd_folders,
    }

    try:
        commands[args.command](args)
    except Exception as e:
        print(json.dumps({"error": str(e)}), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
