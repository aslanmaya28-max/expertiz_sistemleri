from pydantic import BaseModel, Field
from typing import Optional, Any, Dict, List

class VehicleInfo(BaseModel):
    brand: str = Field(..., min_length=1, description="Vehicle brand")
    model: str = Field(..., min_length=1, description="Vehicle model")
    year: int = Field(..., gt=1900, description="Vehicle year")
    km: int = Field(..., ge=0, description="Vehicle kilometers")
    trim: Optional[str] = Field(None, description="Detailed trim level (e.g. Titanium X)")
    fuel: Optional[str] = Field(None, description="Fuel type (Diesel, Petrol, Hybrid, EV)")
    gear: Optional[str] = Field(None, description="Transmission type (Manual, Automatic)")
    color: Optional[str] = Field(None, description="Vehicle color")
    options: List[str] = Field(default=[], description="List of options/packages")
    declaration: Optional[str] = Field(None, description="User declaration regarding vehicle condition")
    tramer: Optional[int] = Field(0, description="Tramer record amount")
    changed_parts: List[str] = Field(default=[], description="List of changed parts")
    painted_parts: List[str] = Field(default=[], description="List of painted parts")

class CaseCreateRequest(BaseModel):
    case_id: Optional[str] = Field(None, description="Optional custom case ID")
    vehicle_info: VehicleInfo

class CaseResponse(BaseModel):
    case_id: str
    status: str
    updated_at: str
    vehicle: Optional[str] = None
    last_version: str

class CaseTimelineItem(BaseModel):
    version: str
    timestamp: str
    hash: str
    predecessor: str

class CaseDetailResponse(BaseModel):
    case_id: str
    history: List[CaseTimelineItem]
    latest: Dict[str, Any]
    latest_json: str
    integrity_verified: bool
