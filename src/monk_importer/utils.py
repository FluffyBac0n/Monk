from __future__ import annotations

import re
from datetime import datetime, time
from typing import Any


def clean_text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def slugify(value: Any) -> str:
    text = clean_text(value) or "unknown"
    text = text.lower()
    text = re.sub(r"[^a-z0-9]+", "-", text)
    return text.strip("-") or "unknown"


def stage_id(sequence: int | None, name: str | None) -> str | None:
    if sequence is None or not name:
        return None
    return f"{sequence}-{slugify(name)}"


def lodging_id(stage_sequence: int | None, stage_name: str | None, lodging_name: str | None, row_number: int) -> str:
    stage_part = stage_id(stage_sequence, stage_name) or f"row-{row_number}"
    lodging_part = slugify(lodging_name or f"lodging-{row_number}")
    return f"{stage_part}-{lodging_part}"


def to_bool_yn(value: Any) -> bool:
    return str(value).strip().upper() == "Y"


def to_float(value: Any) -> float | None:
    if value is None or value == "":
        return None
    if isinstance(value, (int, float)):
        return float(value)
    try:
        return float(str(value).strip())
    except ValueError:
        return None


def to_int(value: Any) -> int | None:
    number = to_float(value)
    if number is None:
        return None
    return int(number)


def parse_price(value: Any) -> tuple[str | None, float | None, float | None]:
    text = clean_text(value)
    if text is None:
        return None, None, None
    numbers = [float(x) for x in re.findall(r"\d+(?:\.\d+)?", text)]
    if not numbers:
        return text, None, None
    if len(numbers) == 1:
        return text, numbers[0], numbers[0]
    return text, numbers[0], numbers[1]


def parse_coordinates(value: Any) -> tuple[float, float] | None:
    text = clean_text(value)
    if not text:
        return None
    parts = [part.strip() for part in text.split(",")]
    if len(parts) != 2:
        return None
    try:
        return float(parts[0]), float(parts[1])
    except ValueError:
        return None


def format_time(value: Any) -> str | None:
    if value is None or value == "":
        return None
    if isinstance(value, datetime):
        return value.strftime("%H:%M")
    if isinstance(value, time):
        return value.strftime("%H:%M")
    return clean_text(value)


def compact_doc(data: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in data.items():
        if value is None:
            continue
        if isinstance(value, dict):
            nested = compact_doc(value)
            if nested:
                result[key] = nested
        elif isinstance(value, list):
            result[key] = value
        else:
            result[key] = value
    return result

