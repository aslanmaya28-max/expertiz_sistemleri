# -*- coding: utf-8 -*-
"""
Arabam v4.0 - Letgo v4.0 Success Pattern Implementation

Target Metrics:
- Success Rate: ≥95%
- Listing Count: ≥15
- Data Accuracy: ≥95%
- Performance: <15s

Architecture:
- 5-Layer Clean Architecture
- 6 Browser Args + 5 JS Stealth Scripts
- 6+ Fallback Selectors Per Field
- 4 URL Fallback Formats
- Paint/Changed Part Extraction (CRITICAL)
"""

__version__ = "4.0.0"

# Main API
from .facade import ArabamScraperFacade

# Models
from .models.listing import ArabamListing
from .models.search_result import ArabamSearchResult
from .models.paint_info import PaintInfo
from .models.package_info import PackageInfo
from .models.enums import (
    FuelType,
    GearType,
    PaintStatus,
    BodyType,
    SellerType,
    WarrantyStatus,
)

__all__ = [
    # API
    "ArabamScraperFacade",
    # Models
    "ArabamListing",
    "ArabamSearchResult",
    "PaintInfo",
    "PackageInfo",
    # Enums
    "FuelType",
    "GearType",
    "PaintStatus",
    "BodyType",
    "SellerType",
    "WarrantyStatus",
]
