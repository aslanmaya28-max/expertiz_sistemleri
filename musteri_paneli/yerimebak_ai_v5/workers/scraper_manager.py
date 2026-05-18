"""
Scraper Manager v1.0
Kaynak bazlı scraper kontrol sistemi
Her kaynak (Arabam, Borusan) için ayrı subprocess yönetimi
"""

import os
import sys
import subprocess
import time
from pathlib import Path
from typing import Dict, Optional
from datetime import datetime


class ScraperManager:
    """Scrapers için subprocess yöneticisi"""
    
    def __init__(self):
        self.base_dir = Path(__file__).parent.parent.parent
        self.pid_dir = Path(__file__).parent
        self.sources = ['arabam', 'borusan']
        
    def _get_pid_path(self, source: str) -> Path:
        """Kaynak için PID dosya yolunu al"""
        return self.pid_dir / f"scraper_{source}.pid"
    
    def _get_log_path(self, source: str) -> Path:
        """Kaynak için log dosya yolunu al"""
        log_dir = self.base_dir / "logs"
        log_dir.mkdir(exist_ok=True)
        return log_dir / f"scraper_{source}_{datetime.now().strftime('%Y%m%d')}.log"
    
    def is_running(self, source: str) -> bool:
        """Scraper'ın çalışıp çalışmadığını kontrol et"""
        pid_path = self._get_pid_path(source)
        
        if not pid_path.exists():
            return False
        
        try:
            with open(pid_path, 'r') as f:
                pid = int(f.read().strip())
            
            # Process'in çalışıp çalışmadığını kontrol et
            # Windows'ta os.kill(pid, 0) çalışmaz, alternatif kullan
            if sys.platform == 'win32':
                # Windows: tasklist ile kontrol et
                result = subprocess.run(
                    ['tasklist', '/FI', f'PID eq {pid}'],
                    capture_output=True,
                    text=True
                )
                return str(pid) in result.stdout
            else:
                # Unix/Linux: os.kill ile kontrol et
                import signal
                os.kill(pid, 0)
                return True
        except (ValueError, ProcessLookupError, OSError):
            # PID dosyası var ama process yok → temizle
            pid_path.unlink(missing_ok=True)
            return False
    
    def start(self, source: str, args: Optional[list] = None, *extra_args, **kwargs) -> tuple[bool, str]:
        """Scraper'ı başlat"""
        if source not in self.sources:
            return False, f"Bilinmeyen kaynak: {source}"
        
        if self.is_running(source):
            return False, f"{source.title()} zaten çalışıyor"
        
        try:
            # Environment variable ayarla
            env = os.environ.copy()
            env['SCRAPER_SOURCE'] = source
            
            # Log dosyasını aç
            log_path = self._get_log_path(source)
            log_file = open(log_path, 'a')
            
            # Subprocess'i başlat
            cmd = [sys.executable, '-m', 'yerimebak_ai_v5.workers.scraper_worker']
            
            process = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=log_file,
                env=env,
                cwd=str(self.base_dir),
                creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if sys.platform == 'win32' else 0
            )
            
            # PID'yi kaydet
            pid_path = self._get_pid_path(source)
            with open(pid_path, 'w') as f:
                f.write(str(process.pid))
            
            return True, f"{source.title()} başlatıldı (PID: {process.pid})"
            
        except Exception as e:
            return False, f"Hata: {str(e)}"
    
    def stop(self, source: str) -> tuple[bool, str]:
        """Scraper'ı durdur"""
        if source not in self.sources:
            return False, f"Bilinmeyen kaynak: {source}"
        
        pid_path = self._get_pid_path(source)
        
        if not pid_path.exists():
            return False, f"{source.title()} zaten durdurulmuş"
        
        try:
            with open(pid_path, 'r') as f:
                pid = int(f.read().strip())
            
            # Process'i sonlandır
            if sys.platform == 'win32':
                # Windows: taskkill kullan
                subprocess.run(['taskkill', '/F', '/PID', str(pid)], 
                             capture_output=True)
            else:
                # Unix/Linux: SIGTERM gönder
                import signal
                os.kill(pid, signal.SIGTERM)
            
            # PID dosyasını sil
            pid_path.unlink(missing_ok=True)
            
            return True, f"{source.title()} durduruldu"
            
        except Exception as e:
            return False, f"Hata: {str(e)}"
    
    def get_status(self, source: str) -> Dict:
        """Scraper durumunu getir"""
        if source not in self.sources:
            return {'error': f'Bilinmeyen kaynak: {source}'}
        
        pid_path = self._get_pid_path(source)
        is_running = self.is_running(source)
        
        status = {
            'source': source,
            'running': is_running,
            'pid': None,
            'start_time': None
        }
        
        if is_running and pid_path.exists():
            try:
                with open(pid_path, 'r') as f:
                    status['pid'] = int(f.read().strip())
                
                # Log dosyasından son aktiviteyi al
                log_path = self._get_log_path(source)
                if log_path.exists():
                    mtime = datetime.fromtimestamp(log_path.stat().st_mtime)
                    status['last_activity'] = mtime.strftime('%d.%m.%Y %H:%M:%S')
            except:
                pass
        
        return status
    
    def get_all_status(self) -> Dict[str, Dict]:
        """Tüm scraper durumlarını getir"""
        return {
            source: self.get_status(source)
            for source in self.sources
        }


# Global instance
_scraper_manager = None

def get_scraper_manager() -> ScraperManager:
    """Global scraper manager instance'ını al"""
    global _scraper_manager
    if _scraper_manager is None:
        _scraper_manager = ScraperManager()
    return _scraper_manager


if __name__ == '__main__':
    # Test
    manager = ScraperManager()
    
    print("=== Scraper Manager Test ===")
    print(f"Base Dir: {manager.base_dir}")
    print(f"PID Dir: {manager.pid_dir}")
    
    print("\n--- Durumlar ---")
    for source, status in manager.get_all_status().items():
        running = "✅ Çalışıyor" if status['running'] else "❌ Durdurulmuş"
        print(f"{source.title()}: {running} (PID: {status.get('pid', 'N/A')})")