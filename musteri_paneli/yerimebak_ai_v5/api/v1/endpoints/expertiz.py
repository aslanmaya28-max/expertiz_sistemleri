# -*- coding: utf-8 -*-
"""
Kurumsal ekspertiz talep API'si.
"""
from typing import Any, Dict, Optional

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, Request, UploadFile
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel

from yerimebak_ai_v5.api.v1.endpoints.auth import get_admin_user, get_authenticated_user
from yerimebak_ai_v5.services import (
    checkout_service,
    customer_service,
    dispatch_service,
    finance_service,
    media_service,
    notification_service,
    invoice_export,
    paytr_service,
    personnel_service,
    pricing_service,
    refund_service,
)
from yerimebak_ai_v5.services.expertiz_service import (
    get_admin_report,
    get_customer_report,
    get_expertiz_packages,
    list_admin_reports,
    list_customer_reports,
    list_customer_requests,
    publish_admin_report,
    reject_admin_report,
)

router = APIRouter()


class CreateExpertizRequest(BaseModel):
    firm_id: str
    package_id: str
    listing_id: Optional[int] = None
    listing_url: Optional[str] = None
    plate: Optional[str] = None
    city: Optional[str] = None
    district: Optional[str] = None
    note: Optional[str] = None
    # Linkle veya elle girilen arac: brand, model, year, km, price, fuel, transmission
    vehicle: Optional[Dict[str, Any]] = None
    # On Bilgilendirme Formu + Mesafeli Satis Sozlesmesi onayi (zorunlu)
    contract_accepted: bool = False


class PricingSettingsRequest(BaseModel):
    service_fee_tl: Optional[float] = None
    vehicle_inflation_monthly_pct: Optional[float] = None
    inflation_note: Optional[str] = None
    inflation_effective_date: Optional[str] = None


class FirmRequest(BaseModel):
    name: Optional[str] = None
    active: Optional[bool] = None
    sort_order: Optional[int] = None
    source_url: Optional[str] = None
    verified: Optional[bool] = None


class PackageRequest(BaseModel):
    name: Optional[str] = None
    price: Optional[float] = None
    features: Optional[Any] = None
    active: Optional[bool] = None
    sort_order: Optional[int] = None


class RejectReportRequest(BaseModel):
    reason: str


class PublishReportRequest(BaseModel):
    admin_note: Optional[str] = None


class AssignRequest(BaseModel):
    personnel_id: str
    note: Optional[str] = None


class UnassignRequest(BaseModel):
    reason: Optional[str] = None


class CustomerStatusRequest(BaseModel):
    active: bool
    reason: Optional[str] = None


class CancelRequestPayload(BaseModel):
    reason: str
    refund: bool = True


class DutyRequest(BaseModel):
    on_duty: bool


class NotificationReadRequest(BaseModel):
    # Bos/None: tum okunmamislar okundu yapilir
    ids: Optional[list] = None


class TaskReportPayload(BaseModel):
    tam_rapor: Dict[str, Any]


def _raise_if_error(result: Dict[str, Any]) -> Dict[str, Any]:
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 400), detail=result["error"])
    return result


def get_personnel_user(user: Dict[str, Any] = Depends(get_authenticated_user)) -> Dict[str, Any]:
    if not dispatch_service.is_personnel(user):
        raise HTTPException(status_code=403, detail="Bu islem sadece saha personeli icindir")
    return user


@router.get("/packages")
async def packages() -> Dict[str, Any]:
    return get_expertiz_packages()


@router.get("/quote")
async def quote(firm_id: str, package_id: str) -> Dict[str, Any]:
    """Hizmet bedeli + paket + KDV toplam tutar (odeme ozeti)."""
    return _raise_if_error(checkout_service.quote_expertiz(firm_id, package_id))


@router.post("/requests")
async def request_expertiz(
    request: CreateExpertizRequest,
    http_request: Request,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    """Ekspertiz talebi + odeme baslatma. Talep, odeme onaylaninca kuyruga duser."""
    ip = paytr_service.client_ip(
        {k.lower(): v for k, v in http_request.headers.items()},
        http_request.client.host if http_request.client else None,
    )
    return _raise_if_error(checkout_service.start_expertiz_checkout(request.model_dump(), user, ip))


@router.get("/requests")
async def my_expertiz_requests(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return list_customer_requests(user)


@router.get("/reports")
async def my_published_reports(
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return list_customer_reports(user)


@router.get("/admin/reports")
async def admin_reports(
    status: Optional[str] = None,
    limit: int = 100,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return list_admin_reports(status=status, limit=limit)


@router.get("/admin/reports/{report_id}")
async def admin_report_detail(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = get_admin_report(report_id)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


@router.post("/admin/reports/{report_id}/reanalyze")
async def admin_reanalyze_report(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Merkezi AI degerlemesini (piyasa + ekspertiz bulgulari) yeniden calistirir."""
    result = await dispatch_service.reanalyze_report(report_id, admin)
    if "error" in result:
        raise HTTPException(status_code=result.get("http_status", 400), detail=result["error"])
    return result


@router.post("/admin/reports/{report_id}/publish")
async def admin_publish_report(
    report_id: str,
    request: Optional[PublishReportRequest] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = publish_admin_report(report_id, admin, admin_note=(request.admin_note if request else None))
    if "error" in result:
        raise HTTPException(status_code=result.get("http_status", 400), detail=result["error"])
    return result


@router.post("/admin/reports/{report_id}/reject")
async def admin_reject_report(
    report_id: str,
    request: RejectReportRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    result = reject_admin_report(report_id, request.reason, admin)
    if "error" in result:
        raise HTTPException(status_code=result.get("http_status", 400), detail=result["error"])
    return result


@router.get("/reports/{report_id}")
async def my_published_report_detail(
    report_id: str,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    result = get_customer_report(report_id, user)
    if "error" in result:
        raise HTTPException(status_code=404, detail=result["error"])
    return result


# ---------------------------------------------------------------------------
# Admin: fiyatlandirma (hizmet bedeli, arac enflasyonu, firma / paket katalogu)
# ---------------------------------------------------------------------------

@router.get("/admin/pricing")
async def admin_pricing(admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    settings = pricing_service.get_pricing_settings()
    return {**settings, "firms": pricing_service.list_firms(include_inactive=True)}


@router.put("/admin/pricing/settings")
async def admin_update_pricing(payload: PricingSettingsRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.update_pricing_settings(payload.model_dump(exclude_none=True), admin))


@router.post("/admin/firms")
async def admin_create_firm(payload: FirmRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.save_firm(payload.model_dump(exclude_none=True)))


@router.put("/admin/firms/{firm_id}")
async def admin_update_firm(firm_id: str, payload: FirmRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.save_firm(payload.model_dump(exclude_none=True), firm_id))


@router.delete("/admin/firms/{firm_id}")
async def admin_deactivate_firm(firm_id: str, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.delete_firm(firm_id))


@router.post("/admin/firms/{firm_id}/packages")
async def admin_create_package(firm_id: str, payload: PackageRequest, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.save_package(firm_id, payload.model_dump(exclude_none=True)))


@router.put("/admin/firms/{firm_id}/packages/{package_id}")
async def admin_update_package(
    firm_id: str, package_id: str, payload: PackageRequest, admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.save_package(firm_id, payload.model_dump(exclude_none=True), package_id))


@router.delete("/admin/firms/{firm_id}/packages/{package_id}")
async def admin_deactivate_package(firm_id: str, package_id: str, admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    return _raise_if_error(pricing_service.delete_package(firm_id, package_id))


@router.get("/admin/finance/summary")
async def admin_finance_summary(
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(finance_service.get_admin_finance_summary())


@router.get("/admin/customers")
async def admin_list_customers(
    search: Optional[str] = None,
    limit: int = 200,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(customer_service.list_customers(search=search, limit=limit))


@router.get("/admin/customers/{customer_id}")
async def admin_customer_detail(
    customer_id: int,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(customer_service.get_customer(customer_id))


@router.post("/admin/customers/{customer_id}/status")
async def admin_set_customer_status(
    customer_id: int,
    payload: CustomerStatusRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(
        customer_service.set_customer_active(customer_id, payload.active, payload.reason or "", admin)
    )


# ---------------------------------------------------------------------------
# Admin: talep kuyrugu ve personel atama
# ---------------------------------------------------------------------------

@router.get("/admin/requests")
async def admin_list_requests(
    bucket: Optional[str] = None,
    region_id: Optional[int] = None,
    il_id: Optional[int] = None,
    limit: int = 300,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.list_admin_requests(bucket=bucket, region_id=region_id, il_id=il_id, limit=limit))


@router.get("/admin/requests/{report_id}")
async def admin_request_detail(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.get_admin_request(report_id))


@router.get("/admin/requests/{report_id}/candidates")
async def admin_request_candidates(
    report_id: str,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.list_candidates(report_id))


@router.post("/admin/requests/{report_id}/assign")
async def admin_assign_request(
    report_id: str,
    request: AssignRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.assign_request(report_id, request.personnel_id, admin, request.note))


@router.post("/admin/requests/{report_id}/cancel")
async def admin_cancel_request(
    report_id: str,
    payload: CancelRequestPayload,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    """Talebi iptal eder; refund=True ise odeme PayTR uzerinden musteriye iade edilir."""
    return _raise_if_error(refund_service.cancel_expertiz_request(report_id, admin, payload.reason, payload.refund))


@router.get("/admin/dashboard")
async def admin_dashboard(admin: Dict[str, Any] = Depends(get_admin_user)) -> Dict[str, Any]:
    """Flutter admin ana ekrani: sayaclar, durum dagilimi, son islemler, trendler."""
    from yerimebak_ai_v5.services import admin_dashboard_service

    return admin_dashboard_service.get_dashboard()


@router.get("/admin/finance/invoices.csv")
async def admin_invoice_export(
    start: Optional[str] = None,
    end: Optional[str] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Response:
    """Muhasebe / e-Arsiv icin tahsilat dokumu (CSV). start/end: YYYY-AA-GG."""
    try:
        rows = invoice_export.collect_rows(start, end)
    except ValueError:
        raise HTTPException(status_code=400, detail="Tarih formati YYYY-AA-GG olmali")
    filename = f"yerimebak_tahsilatlar_{start or 'bu-ay'}_{end or 'bugun'}.csv"
    return Response(
        content=invoice_export.to_csv(rows),
        media_type="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/admin/requests/{report_id}/unassign")
async def admin_unassign_request(
    report_id: str,
    request: Optional[UnassignRequest] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.unassign_request(report_id, admin, request.reason if request else None))


# ---------------------------------------------------------------------------
# Personel: bana atanan gorevler
# ---------------------------------------------------------------------------

@router.get("/personnel/tasks")
async def personnel_tasks(user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return dispatch_service.list_personnel_tasks(user)


@router.post("/personnel/tasks/{report_id}/accept")
async def personnel_accept_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "accept"))


@router.post("/personnel/tasks/{report_id}/start")
async def personnel_start_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "start"))


@router.post("/personnel/tasks/{report_id}/depart")
async def personnel_depart_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    """Harekete gecti: musteri ve admine anlik bildirim."""
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "depart"))


@router.post("/personnel/tasks/{report_id}/arrive")
async def personnel_arrive_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    """Arac basinda."""
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "arrive"))


@router.post("/personnel/tasks/{report_id}/corporate")
async def personnel_corporate_task(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    """Kurumsal ekspertiz noktasinda."""
    return _raise_if_error(dispatch_service.update_task_progress(report_id, user, "corporate"))


@router.get("/personnel/me")
async def personnel_me(user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(personnel_service.get_me(user))


@router.put("/personnel/me/duty")
async def personnel_set_duty(request: DutyRequest, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    """Personel gorev icin aktif/pasif olur; pasif personele yeni gorev atanmaz."""
    return _raise_if_error(personnel_service.set_duty(str(user.get("id")), request.on_duty, user))


@router.put("/admin/personnel/{personnel_id}/duty")
async def admin_set_personnel_duty(
    personnel_id: str,
    request: DutyRequest,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return _raise_if_error(personnel_service.set_duty(personnel_id, request.on_duty, admin, by_admin=True))


# ---------------------------------------------------------------------------
# Bildirimler (musteri / personel / admin)
# ---------------------------------------------------------------------------

@router.get("/notifications")
async def my_notifications(
    limit: int = 30,
    unread_only: bool = False,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return notification_service.list_notifications(user, limit=limit, unread_only=unread_only)


@router.post("/notifications/read")
async def read_my_notifications(
    request: Optional[NotificationReadRequest] = None,
    user: Dict[str, Any] = Depends(get_authenticated_user),
) -> Dict[str, Any]:
    return notification_service.mark_read(user, request.ids if request else None)


@router.get("/admin/notifications")
async def admin_notifications(
    limit: int = 30,
    unread_only: bool = False,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return notification_service.list_notifications(admin, limit=limit, unread_only=unread_only, admin=True)


@router.post("/admin/notifications/read")
async def admin_read_notifications(
    request: Optional[NotificationReadRequest] = None,
    admin: Dict[str, Any] = Depends(get_admin_user),
) -> Dict[str, Any]:
    return notification_service.mark_read(admin, request.ids if request else None, admin=True)



# ---------------------------------------------------------------------------
# Personel: saha raporu, fotograflar, kurumsal rapor, kaydet & gonder
# ---------------------------------------------------------------------------

@router.get("/personnel/tasks/{report_id}/report")
async def personnel_task_report(report_id: str, user: Dict[str, Any] = Depends(get_personnel_user)) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.get_task_report(report_id, user))


@router.put("/personnel/tasks/{report_id}/draft")
async def personnel_save_draft(
    report_id: str,
    payload: TaskReportPayload,
    user: Dict[str, Any] = Depends(get_personnel_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.save_task_draft(report_id, user, payload.tam_rapor))


@router.post("/personnel/tasks/{report_id}/media")
async def personnel_upload_media(
    report_id: str,
    file: UploadFile = File(...),
    category: str = Form("inspection_photo"),
    section: Optional[str] = Form(None),
    item_key: Optional[str] = Form(None),
    item_label: Optional[str] = Form(None),
    note: Optional[str] = Form(None),
    user: Dict[str, Any] = Depends(get_personnel_user),
) -> Dict[str, Any]:
    # Sinirin bir byte fazlasini oku: buyuk dosyalar bellege tamamen alinmaz
    content = await file.read(media_service.MAX_UPLOAD_BYTES + 1)
    return _raise_if_error(
        dispatch_service.upload_task_media(
            report_id, user, content, file.filename, category, section, item_key, item_label, note
        )
    )


@router.delete("/personnel/tasks/{report_id}/media/{media_id}")
async def personnel_delete_media(
    report_id: str,
    media_id: str,
    user: Dict[str, Any] = Depends(get_personnel_user),
) -> Dict[str, Any]:
    return _raise_if_error(dispatch_service.delete_task_media(report_id, media_id, user))


@router.post("/personnel/tasks/{report_id}/submit")
async def personnel_submit_report(
    report_id: str,
    payload: TaskReportPayload,
    background_tasks: BackgroundTasks,
    user: Dict[str, Any] = Depends(get_personnel_user),
) -> Dict[str, Any]:
    result = _raise_if_error(dispatch_service.submit_task_report(report_id, user, payload.tam_rapor))
    # Merkezi AI analizi yanit dondukten sonra calisir; rapor bu arada
    # admin panelinde "Onay Bekleyen" sekmesinde gorunur.
    background_tasks.add_task(dispatch_service.run_central_ai, report_id)
    return result


# ---------------------------------------------------------------------------
# Medya dosyasi (imzali URL ile)
# ---------------------------------------------------------------------------

@router.get("/media/{media_id}")
async def get_media_file(media_id: str, exp: int = 0, sig: str = "") -> FileResponse:
    result = media_service.open_media(media_id, exp, sig)
    if "error" in result:
        raise HTTPException(status_code=int(result.get("http_status") or 404), detail=result["error"])
    return FileResponse(
        result["path"],
        media_type=result["content_type"],
        filename=result["original_name"],
        content_disposition_type="inline",
        headers={"Cache-Control": "private, max-age=3600"},
    )
