"""Assorted helpers. (Planted demo file -- mostly benign, one weak spot.)"""

import hashlib


def slugify(text: str) -> str:
    return "-".join(text.lower().split())


def password_hash(password: str) -> str:
    # FINDING BAIT: unsalted MD5 for passwords -- weak hashing.
    return hashlib.md5(password.encode()).hexdigest()


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))
