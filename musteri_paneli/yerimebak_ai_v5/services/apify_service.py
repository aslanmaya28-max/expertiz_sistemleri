# -*- coding: utf-8 -*-
"""
Apify baglantisi: YerimeBak arac verisi actor'unu calistirir, sonuclari dondurur.

Actor kaynagi: apify/yerimebak-arac-verisi (mod: "ilan" tek ilan, "emsal" emsal aramasi).

Ortam degiskenleri:
  APIFY_MODE      off (varsayilan) | mock | live
  APIFY_TOKEN     Apify API token (yalnizca live; sunucu .env'inde durur)
  APIFY_ACTOR_ID  ornek: kullaniciadi~yerimebak-arac-verisi
  APIFY_TIMEOUT_S bir calistirmanin en uzun suresi (varsayilan 600)
  APIFY_MEMORY_MB actor bellegi (varsayilan 2048; Chromium icin en az 1024)
  APIFY_MOCK_DIR  mock modunda ornek ciktilarin klasoru
                  (varsayilan tests/fixtures/apify)

mock modu ucretsizdir ve internete cikmaz: testler ve uctan uca senaryo bununla calisir.
"""
from __future__ import annotations

import json
import logging
import os
import time
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional

import httpx

logger = logging.getLogger(__name__)

API_BASE = "https://api.apify.com/v2"
FINAL_STATES = {"SUCCEEDED", "FAILED", "TIMED-OUT", "ABORTED"}
DEFAULT_MOCK_DIR = Path(__file__).resolve().parents[2] / "tests" / "fixtures" / "apify"


class ApifyError(RuntimeError):
    """Actor calismadi veya sonuc alinamadi (cagiran taraf kullaniciya sebebi gosterir)."""


def mode() -> str:
    value = (os.getenv("APIFY_MODE") or "off").strip().lower()
    return value if value in ("off", "mock", "live") else "off"


def enabled() -> bool:
    return mode() != "off"


def _mock_items(run_input: Dict[str, Any]) -> List[Dict[str, Any]]:
    """Ornek cikti: once girdiye ozel dosya, yoksa moda gore genel dosya."""
    folder = Path(os.getenv("APIFY_MOCK_DIR") or DEFAULT_MOCK_DIR)
    kind = run_input.get("mode") or "emsal"
    names = []
    if kind == "ilan":
        listing_id = str(run_input.get("url") or "").rstrip("/").split("/")[-1]
        names.append(f"ilan_{listing_id}.json")
    else:
        slug = f"{run_input.get('brand', '')}_{run_input.get('model', '')}".lower().replace(" ", "-")
        names.append(f"emsal_{slug}.json")
    names.append(f"{kind}.json")
    for name in names:
        path = folder / name
        if path.exists():
            data = json.loads(path.read_text(encoding="utf-8"))
            items = data if isinstance(data, list) else data.get("items", [])
            if kind == "ilan":
                items = [dict(it, url=run_input.get("url") or it.get("url")) for it in items]
            return items
    return []


class ApifyClient:
    def __init__(
        self,
        token: Optional[str] = None,
        actor_id: Optional[str] = None,
        transport: Optional[httpx.BaseTransport] = None,
        sleep: Callable[[float], None] = time.sleep,
    ):
        self.token = token or os.getenv("APIFY_TOKEN") or ""
        self.actor_id = (actor_id or os.getenv("APIFY_ACTOR_ID") or "").replace("/", "~")
        self._transport = transport
        self._sleep = sleep

    def _client(self) -> httpx.Client:
        return httpx.Client(
            base_url=API_BASE,
            headers={"Authorization": f"Bearer {self.token}"},
            timeout=httpx.Timeout(90.0, connect=15.0),
            transport=self._transport,
        )

    def run(self, run_input: Dict[str, Any], timeout_s: Optional[int] = None) -> Dict[str, Any]:
        """Actor'u calistirir, bitmesini bekler; {"items": [...], "run": {...}} dondurur."""
        if not self.token or not self.actor_id:
            raise ApifyError("Apify yapilandirilmamis: APIFY_TOKEN ve APIFY_ACTOR_ID gerekli")
        timeout_s = int(timeout_s or os.getenv("APIFY_TIMEOUT_S") or 600)
        memory = int(os.getenv("APIFY_MEMORY_MB") or 2048)
        deadline = time.monotonic() + timeout_s + 60
        with self._client() as client:
            response = client.post(
                f"/acts/{self.actor_id}/runs",
                params={"timeout": timeout_s, "memory": memory, "waitForFinish": 60},
                json=run_input,
            )
            run = self._data(response, "Actor baslatilamadi")
            while run.get("status") not in FINAL_STATES:
                if time.monotonic() > deadline:
                    raise ApifyError(f"Apify calismasi zaman asimina ugradi (run {run.get('id')})")
                self._sleep(2)
                run = self._data(
                    client.get(f"/actor-runs/{run['id']}", params={"waitForFinish": 60}),
                    "Apify calisma durumu alinamadi",
                )
            if run.get("status") != "SUCCEEDED":
                raise ApifyError(
                    f"Apify calismasi basarisiz: {run.get('status')} {run.get('statusMessage') or ''}".strip()
                )
            items_resp = client.get(
                f"/datasets/{run['defaultDatasetId']}/items", params={"clean": "true", "format": "json"}
            )
            if items_resp.status_code >= 400:
                raise ApifyError(f"Apify sonuclari alinamadi (HTTP {items_resp.status_code})")
            items = items_resp.json()
        usage = run.get("usageTotalUsd")
        logger.info(
            "[APIFY] run=%s mode=%s items=%s usd=%s",
            run.get("id"), run_input.get("mode"), len(items), usage,
        )
        return {
            "items": items if isinstance(items, list) else [],
            "run": {
                "id": run.get("id"),
                "status": run.get("status"),
                "started_at": run.get("startedAt"),
                "finished_at": run.get("finishedAt"),
                "usage_usd": usage,
            },
        }

    @staticmethod
    def _data(response: httpx.Response, message: str) -> Dict[str, Any]:
        if response.status_code >= 400:
            detail = ""
            try:
                detail = (response.json().get("error") or {}).get("message", "")
            except Exception:
                pass
            raise ApifyError(f"{message} (HTTP {response.status_code}) {detail}".strip())
        data = response.json().get("data")
        if not isinstance(data, dict):
            raise ApifyError(message)
        return data


def run_actor(run_input: Dict[str, Any], timeout_s: Optional[int] = None) -> Dict[str, Any]:
    """Moda gore actor'u calistirir. off modunda ApifyError verir."""
    current = mode()
    if current == "off":
        raise ApifyError("Apify kapali (APIFY_MODE=off)")
    if current == "mock":
        items = _mock_items(run_input)
        return {"items": items, "run": {"id": "mock", "status": "SUCCEEDED", "usage_usd": 0, "mock": True}}
    return ApifyClient().run(run_input, timeout_s=timeout_s)
