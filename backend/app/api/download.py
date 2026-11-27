"""Public download page for the pilot app: /download (Bangla page) and /download/apk (redirect).

The Pilot APK workflow uploads one APK per processor type and latest.json to the public Supabase
bucket `app-releases`; this page reads latest.json, so a shared link always gives the newest build
to anyone, without a GitHub account.
"""

import html
import time
from typing import Annotated, Any

import httpx2
from fastapi import APIRouter, Depends
from fastapi.responses import HTMLResponse, RedirectResponse

from app.api.legal import _STYLE
from app.config import Settings, get_settings

router = APIRouter(tags=["download"])
SettingsDep = Annotated[Settings, Depends(get_settings)]

_CACHE: dict[str, Any] = {"at": 0.0, "manifest": None}
_TTL_SECONDS = 60


def fetch_manifest(settings: Settings) -> dict | None:
    """latest.json, cached for a minute; None when there is no build or storage is unreachable."""
    if not settings.supabase_url:
        return None
    if _CACHE["manifest"] is not None and time.monotonic() - _CACHE["at"] < _TTL_SECONDS:
        return _CACHE["manifest"]
    url = f"{settings.supabase_url.rstrip('/')}/storage/v1/object/public/app-releases/latest.json"
    try:
        r = httpx2.get(url, timeout=10)
        r.raise_for_status()
        manifest = r.json()
    except (httpx2.HTTPError, ValueError):
        return _CACHE["manifest"]  # last good one, if any
    if not isinstance(manifest, dict) or not isinstance(manifest.get("apks"), dict):
        return None
    _CACHE.update(at=time.monotonic(), manifest=manifest)
    return manifest


def _page(manifest: dict | None) -> str:
    if manifest is None:
        body = "<p>এখন ডাউনলোড পাওয়া যাচ্ছে না। কিছুক্ষণ পরে আবার চেষ্টা করুন।</p>"
    else:
        apks = manifest["apks"]
        build = html.escape(str(manifest.get("build", "")))
        main = html.escape(apks.get("arm64-v8a", ""))
        old = html.escape(apks.get("armeabi-v7a", ""))
        body = f"""
<p>ওষুধের প্রেসক্রিপশনের ছবি তুলুন, অ্যাপ সময়মতো অ্যালার্ম দিয়ে মনে করিয়ে দেবে।
বিনামূল্যে, সাইন ইন ছাড়াই শুরু করা যায়।</p>
<p><a class="btn" href="{main}">ডাউনলোড করুন (Android)</a></p>
<p class="small">সংস্করণ {build} · Android 7.0 বা নতুন ফোনের জন্য</p>
<h2>কীভাবে ইনস্টল করবেন</h2>
<ol>
<li>উপরের বোতামে চাপুন, ফাইলটি ডাউনলোড হবে।</li>
<li>ডাউনলোড শেষ হলে ফাইলটি খুলুন।</li>
<li>ফোন অনুমতি চাইলে "Install unknown apps" / "অজানা অ্যাপ ইনস্টল" চালু করুন।</li>
<li>"Install" চাপুন, তারপর অ্যাপ খুলে "শুরু করুন" চাপুন।</li>
<li>অ্যাপে "রিমাইন্ডার সেটিংস"-এর সব অনুমতি দিন, যেন অ্যালার্ম ঠিক সময়ে বাজে।</li>
</ol>
<p class="small">ফোনটি পুরনো হলে আর অ্যাপ ইনস্টল না হলে <a href="{old}">এই সংস্করণটি</a> চেষ্টা করুন।</p>
<p class="small">এই অ্যাপ ডাক্তারের পরামর্শের বিকল্প নয়।
<a href="/privacy">গোপনীয়তা নীতি</a></p>"""
    return (
        '<!doctype html><html lang="bn"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1">'
        "<title>ওষুধ রিমাইন্ডার · ডাউনলোড</title>"
        f"<style>{_STYLE}"
        ".btn{display:block;text-align:center;background:#176b55;color:#fff;padding:16px;"
        "border-radius:16px;font-size:1.25em;text-decoration:none}.small{font-size:.9em;opacity:.8}"
        "</style></head><body><h1>ওষুধ রিমাইন্ডার</h1>"
        f"{body}</body></html>"
    )


@router.get("/download", response_class=HTMLResponse, include_in_schema=False)
def download_page(settings: SettingsDep) -> str:
    return _page(fetch_manifest(settings))


@router.get("/download/apk", include_in_schema=False)
def download_apk(settings: SettingsDep):
    """Straight to the newest APK for most phones (for QR codes and short links)."""
    manifest = fetch_manifest(settings)
    url = manifest["apks"].get("arm64-v8a") if manifest else None
    if not url:
        return RedirectResponse("/download", status_code=302)
    return RedirectResponse(url, status_code=302)
