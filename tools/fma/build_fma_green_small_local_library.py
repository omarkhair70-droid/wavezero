#!/usr/bin/env python3
"""Build a local WaveZero demo catalog from FMA Green small metadata.

This script intentionally uses only the Python standard library and writes audio
and generated catalog/report files to caller-provided paths so demo content can
stay outside the Git repository.
"""

from __future__ import annotations

import argparse
import csv
import json
import posixpath
import re
import shutil
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Iterable

USAGE_NOTES = (
    "Local FMA demo candidate only. Verify the original FMA track page, "
    "license URL, attribution requirements, and production rights before any "
    "production release."
)
TRUE_VALUES = {"1", "true", "yes", "y", "green", "safe", "strict_green", "small"}
FALSE_VALUES = {"0", "false", "no", "n", "red", "yellow", "unsafe", "blocked"}
GREEN_COLUMNS = (
    "strict_green",
    "is_strict_green",
    "green",
    "is_green",
    "wavezero_green",
    "production_green",
    "license_bucket",
    "license_status_bucket",
    "safety_bucket",
    "decision",
    "status",
)
SUBSET_COLUMNS = ("subset", "fma_subset", "dataset", "split", "archive", "input_subset")
LICENSE_NAME_COLUMNS = ("license_name", "track_license", "license", "license_title")
LICENSE_URL_COLUMNS = ("license_url", "license_uri", "track_license_url", "license")
TITLE_COLUMNS = ("title", "track_title", "track_title_clean", "name")
ARTIST_COLUMNS = ("artist_name", "artist", "artist_title", "creator")
ARTIST_ID_COLUMNS = ("artist_id", "artist_fma_id", "creator_id")
ALBUM_COLUMNS = ("album_name", "album_title", "album")
GENRE_COLUMNS = ("genre_top", "genreTop", "top_genre", "genre")
DURATION_COLUMNS = ("duration_ms", "track_duration_ms", "duration", "track_duration")
ARTWORK_COLUMNS = ("artwork_url", "album_image_file", "track_image_file", "image_url")
SOURCE_URL_COLUMNS = ("source_url", "track_url", "fma_url", "url", "track_page")
ARTIST_URL_COLUMNS = ("artist_url", "artist_website", "artist_page")


@dataclass(frozen=True)
class ZipAudioMember:
    zip_name: str
    relative_path: PurePosixPath
    size: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build a local WaveZero catalog from FMA Green small metadata."
    )
    parser.add_argument("--metadata-dir", required=True, type=Path)
    parser.add_argument("--fma-small-zip", required=True, type=Path)
    parser.add_argument("--input-csv", required=True, type=Path)
    parser.add_argument("--output-audio-dir", required=True, type=Path)
    parser.add_argument("--output-catalog-json", required=True, type=Path)
    parser.add_argument("--output-report-csv", required=True, type=Path)
    parser.add_argument("--audio-base-url", required=True)
    return parser.parse_args()


def fail(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(2)


def require_file(path: Path, label: str) -> None:
    if not path.exists():
        fail(f"{label} does not exist: {path}")
    if not path.is_file():
        fail(f"{label} is not a file: {path}")


def require_directory(path: Path, label: str) -> None:
    if not path.exists():
        fail(f"{label} does not exist: {path}")
    if not path.is_dir():
        fail(f"{label} is not a directory: {path}")


def clean(value: object) -> str:
    return "" if value is None else str(value).strip()


def lower(value: object) -> str:
    return clean(value).lower()


def first_value(row: dict[str, str], names: Iterable[str]) -> str:
    normalized = {key.lower(): key for key in row}
    for name in names:
        key = normalized.get(name.lower())
        if key is not None and clean(row.get(key)):
            return clean(row.get(key))
    return ""


def boolish(value: str) -> bool | None:
    normalized = lower(value)
    if normalized in TRUE_VALUES:
        return True
    if normalized in FALSE_VALUES:
        return False
    return None


def is_green_row(row: dict[str, str], input_csv: Path) -> bool:
    for column in GREEN_COLUMNS:
        value = first_value(row, (column,))
        if not value:
            continue
        flag = boolish(value)
        if flag is not None:
            return flag
        normalized = lower(value)
        if "strict" in normalized and "green" in normalized:
            return True
        if normalized == "green":
            return True
        if any(blocked in normalized for blocked in ("red", "yellow", "unsafe", "blocked")):
            return False
    return "green" in input_csv.name.lower()


def is_small_row(row: dict[str, str], input_csv: Path) -> bool:
    for column in SUBSET_COLUMNS:
        value = first_value(row, (column,))
        if not value:
            continue
        return "small" in lower(value)
    return "small" in input_csv.name.lower()


def track_id_from_row(row: dict[str, str]) -> str:
    raw = first_value(row, ("track_id", "id", "fma_track_id", "track", "track_number"))
    if not raw:
        return ""
    match = re.search(r"\d+", raw)
    return str(int(match.group(0))) if match else raw


def six_digit_track_id(track_id: str) -> str:
    return f"{int(track_id):06d}" if track_id.isdigit() else track_id


def read_candidates(path: Path) -> list[dict[str, str]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
    except UnicodeDecodeError:
        with path.open("r", encoding="utf-8-sig", errors="replace", newline="") as handle:
            rows = list(csv.DictReader(handle))
    if not rows:
        fail(f"input CSV has no rows: {path}")
    return rows


def build_zip_index(zip_path: Path) -> dict[str, ZipAudioMember]:
    index: dict[str, ZipAudioMember] = {}
    try:
        with zipfile.ZipFile(zip_path) as archive:
            for info in archive.infolist():
                if info.is_dir() or not info.filename.lower().endswith(".mp3"):
                    continue
                filename = PurePosixPath(info.filename).name
                match = re.fullmatch(r"(\d+)\.mp3", filename, flags=re.IGNORECASE)
                if not match:
                    continue
                track_id = str(int(match.group(1)))
                relative = normalized_audio_relative_path(info.filename)
                index[track_id] = ZipAudioMember(info.filename, relative, info.file_size)
    except zipfile.BadZipFile:
        fail(f"fma_small.zip is not a readable ZIP archive: {zip_path}")
    if not index:
        fail(f"no MP3 files were found in ZIP archive: {zip_path}")
    return index


def normalized_audio_relative_path(zip_name: str) -> PurePosixPath:
    parts = list(PurePosixPath(zip_name).parts)
    if parts and parts[0].lower() == "fma_small":
        parts = parts[1:]
    if not parts:
        fail(f"invalid MP3 path in archive: {zip_name}")
    if any(part in ("", ".", "..") for part in parts):
        fail(f"unsafe MP3 path in archive: {zip_name}")
    return PurePosixPath(*parts)


def safe_extract_member(zip_path: Path, member: ZipAudioMember, output_dir: Path) -> Path:
    destination = output_dir.joinpath(*member.relative_path.parts)
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and destination.stat().st_size == member.size:
        return destination
    with zipfile.ZipFile(zip_path) as archive:
        with archive.open(member.zip_name) as source, destination.open("wb") as target:
            shutil.copyfileobj(source, target)
    return destination


def parse_duration_ms(value: str) -> int:
    if not value:
        return 0
    try:
        number = float(value)
    except ValueError:
        return 0
    if number <= 0:
        return 0
    return int(round(number if number > 10_000 else number * 1000))


def license_status(license_name: str, license_url: str) -> str:
    text = f"{license_name} {license_url}".lower()
    if "cc0" in text or "public domain" in text or "zero/1.0" in text:
        return "public_domain"
    if "by" in text or "attribution" in text or "sharealike" in text or "by-sa" in text:
        return "attribution_required"
    return "license_pending"


def bool_license_capability(status: str, license_name: str, license_url: str, capability: str) -> bool:
    text = f"{license_name} {license_url}".lower()
    if status == "license_pending":
        return False
    if capability == "commercial" and ("noncommercial" in text or "by-nc" in text or "nc-" in text):
        return False
    if capability == "derivatives" and ("no derivatives" in text or "noderivatives" in text or "by-nd" in text or "nd/" in text):
        return False
    return True


def join_url(base_url: str, relative_path: PurePosixPath) -> str:
    base = base_url.rstrip("/")
    return f"{base}/{posixpath.join(*relative_path.parts)}"


def source_url_for(row: dict[str, str], track_id: str) -> str:
    explicit = first_value(row, SOURCE_URL_COLUMNS)
    if explicit:
        return explicit
    return f"https://freemusicarchive.org/music/track/{track_id}/"


def build_catalog_track(row: dict[str, str], member: ZipAudioMember, audio_url: str) -> tuple[dict[str, object], dict[str, object]]:
    track_id = track_id_from_row(row)
    artist_name = first_value(row, ARTIST_COLUMNS) or "Unknown FMA Artist"
    artist_id_raw = first_value(row, ARTIST_ID_COLUMNS)
    artist_id = f"fma-artist-{artist_id_raw}" if artist_id_raw else f"fma-artist-{slugify(artist_name)}"
    title = first_value(row, TITLE_COLUMNS) or f"FMA Track {track_id}"
    license_name = first_value(row, LICENSE_NAME_COLUMNS)
    license_url = first_value(row, LICENSE_URL_COLUMNS)
    status = license_status(license_name, license_url)
    attribution_required = status == "attribution_required"
    source_url = source_url_for(row, track_id)
    asset = {
        "id": f"asset-fma-{six_digit_track_id(track_id)}-mp3",
        "track_id": f"track-fma-{six_digit_track_id(track_id)}",
        "manifest_url": audio_url,
        "stream_url": audio_url,
        "asset_url": audio_url,
        "codec": "mp3",
        "bitrate_kbps": 0,
        "segment_count": 1,
        "is_primary": True,
        "quality_label": "standard",
        "sample_rate_hz": None,
        "bit_depth": None,
        "file_size_bytes": member.size,
    }
    track = {
        "id": f"track-fma-{six_digit_track_id(track_id)}",
        "artist_id": artist_id,
        "artist_name": artist_name,
        "title": title,
        "duration_ms": parse_duration_ms(first_value(row, DURATION_COLUMNS)),
        "artwork_url": first_value(row, ARTWORK_COLUMNS) or None,
        "album_name": first_value(row, ALBUM_COLUMNS) or None,
        "sourceType": "fma_green_small_local_demo",
        "productionSafe": True,
        "genreTop": first_value(row, GENRE_COLUMNS) or None,
        "assets": [asset],
        "licenseStatus": status,
        "licenseName": license_name or None,
        "licenseUrl": license_url or None,
        "sourceName": "Free Music Archive",
        "sourceUrl": source_url,
        "artistUrl": first_value(row, ARTIST_URL_COLUMNS) or None,
        "attributionText": f"{title} by {artist_name} via Free Music Archive",
        "attributionRequired": attribution_required,
        "commercialUseAllowed": bool_license_capability(status, license_name, license_url, "commercial"),
        "redistributionAllowed": status != "license_pending",
        "derivativesAllowed": bool_license_capability(status, license_name, license_url, "derivatives"),
        "usageNotes": USAGE_NOTES,
    }
    artist = {"id": artist_id, "name": artist_name, "image_url": None}
    return track, artist


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug or "unknown"


def write_json(path: Path, payload: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def write_report(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = ["track_id", "status", "zip_member", "relative_audio_path", "title", "artist_name", "message"]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def main() -> None:
    args = parse_args()
    require_directory(args.metadata_dir, "metadata directory")
    require_file(args.fma_small_zip, "fma_small.zip")
    require_file(args.input_csv, "input CSV")
    if not args.audio_base_url.startswith(("http://", "https://")):
        fail("--audio-base-url must start with http:// or https://")

    rows = read_candidates(args.input_csv)
    green_small_rows = [row for row in rows if is_green_row(row, args.input_csv) and is_small_row(row, args.input_csv)]
    if not green_small_rows:
        fail("input CSV did not contain any rows matching strict Green + subset small")

    zip_index = build_zip_index(args.fma_small_zip)
    args.output_audio_dir.mkdir(parents=True, exist_ok=True)

    artists_by_id: dict[str, dict[str, object]] = {}
    tracks: list[dict[str, object]] = []
    assets: list[dict[str, object]] = []
    report_rows: list[dict[str, object]] = []

    for row in green_small_rows:
        track_id = track_id_from_row(row)
        if not track_id:
            report_rows.append({"track_id": "", "status": "missing_id", "zip_member": "", "relative_audio_path": "", "title": first_value(row, TITLE_COLUMNS), "artist_name": first_value(row, ARTIST_COLUMNS), "message": "No track ID column was found for this row."})
            continue
        member = zip_index.get(track_id)
        if member is None:
            report_rows.append({"track_id": track_id, "status": "missing_audio", "zip_member": "", "relative_audio_path": "", "title": first_value(row, TITLE_COLUMNS), "artist_name": first_value(row, ARTIST_COLUMNS), "message": f"Missing {six_digit_track_id(track_id)}.mp3 in fma_small.zip."})
            continue
        extracted_path = safe_extract_member(args.fma_small_zip, member, args.output_audio_dir)
        audio_url = join_url(args.audio_base_url, member.relative_path)
        track, artist = build_catalog_track(row, member, audio_url)
        tracks.append(track)
        artists_by_id.setdefault(str(artist["id"]), artist)
        assets.extend(track["assets"])
        report_rows.append({"track_id": track_id, "status": "imported", "zip_member": member.zip_name, "relative_audio_path": extracted_path.relative_to(args.output_audio_dir).as_posix(), "title": track["title"], "artist_name": track["artist_name"], "message": ""})

    artists = sorted(artists_by_id.values(), key=lambda artist: str(artist["name"]).lower())
    tracks.sort(key=lambda track: (str(track["artist_name"]).lower(), str(track["title"]).lower(), str(track["id"])))
    assets.sort(key=lambda asset: str(asset["id"]))

    write_json(args.output_catalog_json, {"artists": artists, "tracks": tracks, "assets": assets})
    write_report(args.output_report_csv, report_rows)

    imported = sum(1 for row in report_rows if row["status"] == "imported")
    missing = len(green_small_rows) - imported
    print(f"Green small input: {len(green_small_rows)}")
    print(f"Imported audio: {imported}")
    print(f"Missing: {missing}")
    print(f"Artists: {len(artists)}")
    print(f"Audio folder: {args.output_audio_dir}")
    print(f"Catalog JSON: {args.output_catalog_json}")
    print(f"Report CSV: {args.output_report_csv}")
    if missing:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
