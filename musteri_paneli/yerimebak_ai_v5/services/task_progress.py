# -*- coding: utf-8 -*-
"""
Saha gorevinin adimlari ve musteriye gosterilen canli durum.

Atama durumu (reports.data.assignment.status) sirasiyla ilerler:
  assigned -> accepted -> on_the_way -> at_vehicle -> at_corporate -> in_progress -> submitted
Personel adim atlayabilir (or. aracla dogrudan kurumsal firmada bulusma) ama geri gidemez.
Admin raporu reddederse rapor 'rejected' olur ve personel 'start' ile duzeltmeye doner.
"""
from typing import Any, Dict, List, Optional

STAGES = ("assigned", "accepted", "on_the_way", "at_vehicle", "at_corporate", "in_progress", "submitted")

# personel islemi -> hedef adim ve zaman damgasi alani
ACTIONS = {
    "accept": ("accepted", "accepted_at"),
    "depart": ("on_the_way", "departed_at"),
    "arrive": ("at_vehicle", "arrived_at"),
    "corporate": ("at_corporate", "corporate_at"),
    "start": ("in_progress", "started_at"),
}

# reports.durum / talep.durum metinleri (admin ve personel listelerinde gorunur)
DURUM_BY_STAGE = {
    "unassigned": "Beklemede",
    "assigned": "Personele Atandı",
    "accepted": "Personel Kabul Etti",
    "on_the_way": "Harekete Geçti",
    "at_vehicle": "Araç Başında",
    "at_corporate": "Kurumsal Ekspertizde",
    "in_progress": "İncelemede",
    "submitted": "Rapor Gönderildi",
}
DURUM_REJECTED = "Düzeltme Gerekli"
DURUM_PUBLISHED = "Tamamlandı"

STAGE_LABELS = {
    "unassigned": "Atama bekliyor",
    "assigned": "Personele atandı",
    "accepted": "Görev kabul edildi",
    "on_the_way": "Harekete geçti",
    "at_vehicle": "Araç başında",
    "at_corporate": "Kurumsal ekspertizde",
    "in_progress": "Rapor hazırlanıyor",
    "submitted": "Rapor gönderildi",
}

# Bildirim metinleri: (musteriye, admine)
CUSTOMER_MESSAGES = {
    "accept": None,
    "depart": ("Uzmanınız yola çıktı", "Ekspertiz uzmanınız {person} aracınız için harekete geçti."),
    "arrive": ("Uzmanınız araç başında", "{person} şu anda aracınızın başında, incelemeye başlıyor."),
    "corporate": ("Aracınız kurumsal ekspertizde", "Aracınız {firm} kurumsal ekspertiz noktasında inceleniyor."),
    "start": ("Raporunuz hazırlanıyor", "{person} ekspertiz raporunuzu hazırlıyor."),
}
ADMIN_MESSAGES = {
    "accept": ("Görev kabul edildi", "{person} {vehicle} görevini kabul etti."),
    "depart": ("Personel harekete geçti", "{person} {vehicle} için yola çıktı."),
    "arrive": ("Personel araç başında", "{person} {vehicle} aracının başında."),
    "corporate": ("Kurumsal ekspertizde", "{person} {vehicle} ile {firm} noktasında."),
    "start": ("Rapor hazırlanıyor", "{person} {vehicle} raporunu hazırlıyor."),
}


def stage_index(stage: Optional[str]) -> int:
    try:
        return STAGES.index(stage or "assigned")
    except ValueError:
        return 0


def can_transition(current: str, target: str, report_status: str) -> bool:
    """Ileri adimlara gecis serbest; reddedilen rapor icin 'in_progress'e donus serbest."""
    if target == "in_progress" and current == "submitted":
        return report_status == "rejected"
    return stage_index(target) > stage_index(current)


def next_actions(current: str, report_status: str, corporate_required: bool) -> List[str]:
    """Personel ekraninda gosterilecek dugmeler (sirali)."""
    if report_status not in ("draft", "rejected"):
        return []
    actions = []
    for action, (target, _) in ACTIONS.items():
        if action == "corporate" and not corporate_required:
            continue
        if can_transition(current, target, report_status):
            actions.append(action)
    return actions


def _step(key: str, label: str, at: Any, done: bool) -> Dict[str, Any]:
    return {"key": key, "label": label, "at": at, "done": bool(done)}


def customer_timeline(
    report_status: str,
    created_at: Any,
    assignment: Dict[str, Any],
    corporate_required: bool,
    published_at: Any = None,
    person_name: str = "",
) -> Dict[str, Any]:
    """Musteriye gosterilen canli durum. Admin reddi musteriye gosterilmez ('kontrol ediliyor')."""
    assignment = assignment if isinstance(assignment, dict) else {}
    stage = assignment.get("status") if assignment.get("personnel_id") else "unassigned"
    idx = stage_index(stage) if stage != "unassigned" else -1
    in_review = report_status in ("pending_ai", "pending_admin", "rejected")
    published = report_status == "published"

    steps = [
        _step("received", "Talebiniz alındı", created_at, True),
        _step("assigned", "Ekspertiz uzmanı atandı", assignment.get("assigned_at"), idx >= 0 or in_review or published),
        _step("on_the_way", "Uzman harekete geçti", assignment.get("departed_at"), bool(assignment.get("departed_at")) or idx >= stage_index("on_the_way")),
        _step("at_vehicle", "Uzman araç başında", assignment.get("arrived_at"), bool(assignment.get("arrived_at")) or idx >= stage_index("at_vehicle")),
    ]
    if corporate_required:
        steps.append(
            _step("at_corporate", "Kurumsal ekspertizde", assignment.get("corporate_at"),
                  bool(assignment.get("corporate_at")) or idx >= stage_index("at_corporate"))
        )
    steps += [
        _step("reporting", "Rapor hazırlanıyor", assignment.get("started_at"), idx >= stage_index("in_progress") or in_review or published),
        _step("review", "Rapor kontrol ediliyor", assignment.get("submitted_at"), in_review or published),
        _step("ready", "Raporunuz hazır", published_at, published),
    ]
    # Atlanan adimlar (tarih yok, sonraki adim tamam) tamamlanmis sayilir
    for i in range(len(steps) - 2, -1, -1):
        if steps[i + 1]["done"]:
            steps[i]["done"] = True

    current = next((s for s in steps if not s["done"]), None)
    last_done = [s for s in steps if s["done"]][-1]
    return {
        "stage": "published" if published else ("review" if in_review else stage),
        "label": last_done["label"],
        "next_label": current["label"] if current else None,
        "person_name": short_name(person_name) if idx >= 0 or in_review or published else "",
        "steps": steps,
    }


def short_name(full_name: str) -> str:
    """Musteriye gosterilen personel adi: 'Ahmet Yilmaz' -> 'Ahmet Y.'"""
    parts = [p for p in str(full_name or "").split() if p]
    if not parts:
        return ""
    if len(parts) == 1:
        return parts[0]
    return f"{' '.join(parts[:-1])} {parts[-1][0]}."
