# -*- coding: utf-8 -*-
"""
YERİMEBAK AI – ANTIGRAVITY v5.2+ SaaS CORE
Evidence Package: The Unit of Forensic Truth
"""

import json
import uuid
from datetime import datetime
from typing import Dict, Any, List, Optional
try:
    from .forensic_sealing import ForensicSealer
    from yerimebak_ai_v5.core.market.normalization import NormalizationLayer
except (ImportError, ValueError):
    from .forensic_sealing import ForensicSealer
    from yerimebak_ai_v5.core.market.normalization import NormalizationLayer

class EvidencePackage:
    """
    The heart of the system. A single immutable bundle of truth.
    """
    def __init__(self, case_id: str, version: int = 1):
        self.package_id = f"PKG-{uuid.uuid4().hex[:8].upper()}"
        self.case_id = case_id
        self.version = version
        self.created_at = datetime.now().isoformat()
        
        self.sources = {
            "urls": [],
            "uploaded_files": [],
            "images": [],
            "manual_inputs": {}
        }
        
        self.normalized_snapshot = {}
        self.extracted_signals = {}
        
        self.forensic_metadata = {
            "hash_algorithm": "SHA3-512",
            "package_hash": None,
            "previous_package_hash": None
        }

    def to_dict(self) -> Dict[str, Any]:
        return {
            "package_id": self.package_id,
            "case_id": self.case_id,
            "version": self.version,
            "created_at": self.created_at,
            "sources": self.sources,
            "normalized_snapshot": self.normalized_snapshot,
            "extracted_signals": self.extracted_signals,
            "forensic_metadata": self.forensic_metadata
        }

class EvidencePackageBuilder:
    """Builder pattern for EvidencePackage construction"""
    
    def __init__(self, case_id: str, version: int = 1):
        self.package = EvidencePackage(case_id, version)
        self.normalizer = NormalizationLayer()
        self.sealer = ForensicSealer()

    def add_source_url(self, url: str):
        self.package.sources["urls"].append(url)
        return self

    def add_manual_input(self, data: Dict[str, Any]):
        self.package.sources["manual_inputs"] = data
        return self

    def add_image(self, image_id: str):
        self.package.sources["images"].append(image_id)
        return self

    def add_file(self, filename: str, content_type: str, file_hash: str):
        self.package.sources["uploaded_files"].append({
            "filename": filename,
            "content_type": content_type,
            "file_hash": file_hash,
            "timestamp": datetime.now().isoformat()
        })
        return self

    def compile(self) -> EvidencePackage:
        """Runs Normalization & Signal Extraction"""
        # 1. Normalize combined inputs
        raw_combined = self.package.sources["manual_inputs"].copy()
        # Merge other signals if needed
        
        self.package.normalized_snapshot = self.normalizer.normalize_vehicle(raw_combined)
        self.package.extracted_signals = {}
        
        return self.package

    def seal(self, package: EvidencePackage, prev_hash: Optional[str] = None):
        """Generates the Forensic Seal"""
        package.forensic_metadata["previous_package_hash"] = prev_hash
        
        # Prepare data for sealing (excluding the hash field itself)
        data_to_seal = package.to_dict()
        data_to_seal["forensic_metadata"]["package_hash"] = None
        
        package.forensic_metadata["package_hash"] = self.sealer.generate_seal(data_to_seal)
        return package
