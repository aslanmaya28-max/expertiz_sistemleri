# -*- coding: utf-8 -*-
"""
YERİMEBAK AI – ANTIGRAVITY v5.2 SaaS CORE
Evidence Vault: Immutable, Hash-Addressable Storage
"""

import json
import os
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Any
try:
    from .forensic_sealing import ForensicSealer
except (ImportError, ValueError):
    from forensic_sealing import ForensicSealer

class EvidenceVault:
    """
    SaaS-Grade Evidence Vault.
    Properties: Append-only, Hash-addressable, Immutable.
    """
    
    def __init__(self, base_path: str = "yerimebak_ai_v5/data/vault"):
        self.base_path = Path(base_path)
        self.base_path.mkdir(parents=True, exist_ok=True)
        self.sealer = ForensicSealer()

    def store_record(self, record: dict, vault_key: str = None) -> str:
        """
        GÖREV: Evidence Sealing & Storage (Stage 5 & 6)
        Stores a record with version chain integrity.
        """
        # Use vault_key (Case ID) if provided, otherwise fallback to analysis_id
        storage_id = vault_key or record.get("analysis_id")
        if not storage_id:
            raise ValueError("ARCHITECTURAL_ERROR: Record must have a vault_key or analysis_id.")

        # Determine Versioning
        version_folder = self.base_path / storage_id
        version_folder.mkdir(exist_ok=True)
        
        # Count existing versions to determine current vX
        existing_versions = sorted(list(version_folder.glob("v*.json")), key=lambda x: int(x.stem[1:]))
        v_num = len(existing_versions) + 1
        v_tag = f"v{v_num}"
        
        # Link to predecessor if applicable (IMUTABLE CHAIN)
        if v_num > 1:
            prev_file = existing_versions[-1]
            with open(prev_file, 'r', encoding='utf-8') as f:
                prev_data = json.load(f)
                record["predecessor_hash"] = prev_data.get("seal")
                record["version"] = v_num
        else:
            record["version"] = 1
        
        target_file = version_folder / f"{v_tag}.json"
        
        # Final Safeguard: Never overwrite
        if target_file.exists():
             raise FileExistsError(f"VAULT_INTEGRITY_FAULT: Version {v_tag} already exists for {storage_id}")

        # Write as Read-Only (Simulation)
        with open(target_file, 'w', encoding='utf-8') as f:
            json.dump(record, f, indent=2, ensure_ascii=False)
        
        return str(target_file)

    def list_cases(self) -> List[Dict[str, Any]]:
        """
        Retrieves all cases in the vault for the Case List UI.
        """
        cases = []
        for case_dir in self.base_path.iterdir():
            if case_dir.is_dir():
                versions = sorted(list(case_dir.glob("v*.json")), key=lambda x: int(x.stem[1:]))
                if versions:
                    # Get latest version data for summary
                    with open(versions[-1], 'r', encoding='utf-8') as f:
                        latest_data = json.load(f)
                        cases.append({
                            "case_id": case_dir.name,
                            "last_version": f"v{len(versions)}",
                            "updated_at": latest_data.get("metadata", {}).get("timestamp", "N/A"),
                            "status": latest_data.get("status", "UNKNOWN"),
                            "vehicle": latest_data.get("valuation", {}).get("raw_input", {}).get("brand", "N/A")
                        })
        return cases

    def get_case_timeline(self, case_id: str) -> List[Dict[str, Any]]:
        """
        Retrieves full history for a case (Version Timeline).
        """
        timeline = []
        case_dir = self.base_path / case_id
        if case_dir.exists():
            versions = sorted(list(case_dir.glob("v*.json")), key=lambda x: int(x.stem[1:]))
            for v_file in versions:
                with open(v_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    timeline.append({
                        "version": v_file.stem,
                        "timestamp": data.get("metadata", {}).get("timestamp", "N/A"),
                        "hash": data.get("seal", "N/A")[:16] + "...",
                        "predecessor": data.get("predecessor_hash", "NONE")[:16] + "..." if data.get("predecessor_hash") else "START"
                    })
        return timeline

    def verify_vault_integrity(self, analysis_id: str, version: str = "v1") -> bool:
        """
        Verifies recorded data against its digital seal.
        """
        target_file = self.base_path / analysis_id / f"{version}.json"
        if not target_file.exists():
            return False
            
        with open(target_file, 'r', encoding='utf-8') as f:
            data = json.load(f)
            provided_seal = data.pop("seal", None)
            return self.sealer.verify_seal(data, provided_seal)
