from typing import TypedDict, Optional, List
from datetime import datetime

class Listing(TypedDict):
    id: Optional[int]
    brand: str
    model: str
    year: int
    price: int
    km: int
    fuel: Optional[str]  # Legacy, kept for backward compatibility
    fuel_type: Optional[str]  # New field - preferred
    transmission: Optional[str]
    source: str
    url: str
    image_url: Optional[str]
    listing_date: Optional[str]  # İlan tarihi - ISO format
    created_at: Optional[str]
    updated_at: Optional[str]

class PriceHistory(TypedDict):
    id: Optional[int]
    listing_id: int
    price: int
    recorded_at: str
