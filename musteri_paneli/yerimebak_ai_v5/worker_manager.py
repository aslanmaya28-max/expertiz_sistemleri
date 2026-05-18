# -*- coding: utf-8 -*-
"""
YERIMEBAK AI - Worker Manager (Watchdog)
Monitors and manages background workers (Scraper, Alert, Analytics).
"""
import signal
import subprocess
import time
import sys
import os

_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
_ROOT_DIR = os.path.dirname(_THIS_DIR)

WORKERS = [
    {"name": "Scraper Worker", "script": "yerimebak_ai_v5.workers.scraper_worker"},
    {"name": "Alert Worker", "script": "yerimebak_ai_v5.workers.alert_worker"},
    {"name": "Cleanup Worker", "script": "yerimebak_ai_v5.workers.maintenance.cleanup_worker"},
]

# Build worker lookup dict once to avoid StopIteration risk
WORKER_BY_NAME = {w["name"]: w for w in WORKERS}

MAX_RESTART_BACKOFF = 300  # 5 minutes max backoff


def start_worker(worker):
    print(f"{worker['name']} baslatiliyor...")
    return subprocess.Popen(
        [sys.executable, "-m", worker['script']],
        cwd=_ROOT_DIR
    )


def _reap_zombie(proc):
    """Reap a terminated child process to prevent zombie."""
    try:
        proc.wait(timeout=5)
    except Exception:
        pass


def main():
    print(f"{'='*50}")
    print("YERIMEBAK AI v8.1 WORKER MANAGER")
    print(f"{'='*50}")
    
    processes = {}
    restart_counts = {}
    last_restart_time = {}
    
    for w in WORKERS:
        processes[w['name']] = start_worker(w)
        restart_counts[w['name']] = 0
        last_restart_time[w['name']] = time.time()
    
    # 🔒 DÜZELTİLDİ (H4): SIGCHLD handler — zombie process'leri reaper
    def _sigchld_handler(signum, frame):
        for name, proc in list(processes.items()):
            if proc.poll() is not None:
                _reap_zombie(proc)
    try:
        signal.signal(signal.SIGCHLD, _sigchld_handler)
    except (AttributeError, ValueError):
        pass  # Windows'ta SIGCHLD yok
    
    try:
        while True:
            now = time.time()
            for name, proc in list(processes.items()):
                if proc.poll() is not None:
                    time_since_last = now - last_restart_time.get(name, now)
                    restart_counts[name] = restart_counts.get(name, 0) + 1
                    
                    backoff = min(10 * (2 ** (restart_counts[name] - 1)), MAX_RESTART_BACKOFF)
                    
                    if time_since_last < 60:
                        restart_counts[name] += 1
                    else:
                        restart_counts[name] = 1
                    
                    print(f"{name} DURDU! (yeniden baslatma #{restart_counts[name]}, bekleme: {backoff}s)")
                    _reap_zombie(proc)
                    time.sleep(backoff)
                    
                    # 🔒 DÜZELTİLDİ (H5): StopIteration riski giderildi — dict lookup kullaniliyor
                    worker_info = WORKER_BY_NAME.get(name)
                    if worker_info is None:
                        print(f"❌ Bilinmeyen worker: {name}, atlaniyor")
                        continue
                    processes[name] = start_worker(worker_info)
                    last_restart_time[name] = time.time()
            time.sleep(10)
    except KeyboardInterrupt:
        print("\nManager durduruluyor...")
        for name, proc in list(processes.items()):
            print(f"{name} kapatiliyor...")
            proc.terminate()
            _reap_zombie(proc)

if __name__ == "__main__":
    main()

