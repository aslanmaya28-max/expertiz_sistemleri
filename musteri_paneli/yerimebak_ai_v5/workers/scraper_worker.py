import asyncio
import os
import signal
import sys
import time

from yerimebak_ai_v5.core.auto_analyzer import analyze_listing
from yerimebak_ai_v5.core.config import DEFAULT_HEADLESS
from yerimebak_ai_v5.core.logger import get_logger
from yerimebak_ai_v5.data_lake.repository import get_repository
from yerimebak_ai_v5.workers.scraper_backfill_planner import ScraperBackfillPlanner
from yerimebak_ai_v5.workers.turkey_targets import TURKEY_2EL_TARGETS


logger = get_logger("ScraperWorker")


class ScraperWorker:
    TARGETS = TURKEY_2EL_TARGETS

    def __init__(self, planner=None):
        self.repository = get_repository()
        self.running = True
        self.planner = planner or ScraperBackfillPlanner()

        self.scraper_source = os.getenv("SCRAPER_SOURCE", "all").lower()
        self.scrapers = {}

    def _init_scrapers(self):
        """Lazy load scrapers based on SCRAPER_SOURCE."""
        from yerimebak_ai_v5.scrapers.arabam_smart import ArabamSmartCollector
        from yerimebak_ai_v5.scrapers.borusan_smart import BorusanSmartScraper

        if self.scraper_source == "arabam":
            self.scrapers = {
                "arabam": ArabamSmartCollector(headless=DEFAULT_HEADLESS),
            }
            logger.info(f"Scraper initialized: {self.scraper_source}")
        elif self.scraper_source == "borusan":
            self.scrapers = {
                "borusan": BorusanSmartScraper(),
            }
            logger.info(f"Scraper initialized: {self.scraper_source}")
        else:
            self.scrapers = {
                "arabam": ArabamSmartCollector(headless=DEFAULT_HEADLESS),
                "borusan": BorusanSmartScraper(),
            }
            logger.info("Scrapers initialized: arabam, borusan (all)")

    async def run(self):
        pid_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scraper_worker.pid")
        with open(pid_path, "w") as f:
            f.write(str(os.getpid()))

        try:
            logger.info(f"Starting Production Market Data Lake Scraper Worker (PID: {os.getpid()})...")
            self._init_scrapers()

            while self.running:
                try:
                    cycle_start = time.time()
                    await self.process_scrape_jobs()

                    duration = time.time() - cycle_start
                    if self.running:
                        sleep_time = 300 if duration < 600 else 600
                        logger.info(f"Cycle completed in {duration / 60:.1f}m. Sleeping for {sleep_time / 60:.1f}m...")
                        await asyncio.sleep(sleep_time)
                except Exception as exc:
                    logger.error(f"Worker cycle failed: {exc}", exc_info=True)
                    await asyncio.sleep(60)
        finally:
            if os.path.exists(pid_path):
                os.remove(pid_path)

    async def process_scrape_jobs(self):
        jobs = self.planner.build_jobs()
        logger.info(f"Scraper planner produced {len(jobs)} jobs")

        for job in jobs:
            if not self.running:
                break

            brand = job["brand"]
            model = job["model"]
            year = int(job["year"])
            segment = job.get("segment", "-")
            mode = job.get("mode", "unknown")
            reason = job.get("reason", "-")

            logger.info(f"Market Backfill: {brand} {model} {year} ({segment}) mode={mode} reason={reason}")
            await self.process_vehicle(brand, model, year)
            await asyncio.sleep(2)

    async def process_vehicle(self, brand: str, model: str, year: int):
        if self.scraper_source in self.scrapers:
            await self.scrape_source(self.scraper_source, brand, model, year)
            return

        tasks = [
            self.scrape_source("arabam", brand, model, year),
            self.scrape_source("borusan", brand, model, year),
        ]
        await asyncio.gather(*tasks)

    async def scrape_source(self, source: str, brand: str, model: str, year: int):
        try:
            logger.info(f"   Searching {source} for {brand} {model} {year}")

            scraper = self.scrapers.get(source)
            if not scraper:
                logger.error(f"Scraper {source} not found")
                return

            if source == "borusan":
                listings = await scraper.collect_data(brand=brand, year_min=year - 3, year_max=year + 3, model=model, only_new=True)
            else:
                listings = await scraper.collect_data(brand, model, year, only_new=True)

            for item in listings:
                item["source"] = source

                listing_id = await self.repository.save_listing(item)

                if listing_id and listing_id > 0:
                    try:
                        analyze_listing(listing_id)
                    except Exception as exc:
                        logger.warning(f"   Auto-analyze failed for listing {listing_id}: {exc}")

            logger.info(f"   Saved {len(listings)} listings from {source}")
        except Exception as exc:
            logger.warning(f"   {source} failed for {brand} {model}: {exc}")

    def stop(self):
        logger.info("Stopping worker...")
        self.running = False


def main():
    worker = ScraperWorker()

    loop = asyncio.get_event_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, worker.stop)
        except NotImplementedError:
            pass

    try:
        asyncio.run(worker.run())
    except KeyboardInterrupt:
        logger.info("Worker stopped by user")
    except Exception as exc:
        logger.critical(f"Worker crashed: {exc}", exc_info=True)
        sys.exit(1)
    finally:
        pid_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "scraper_worker.pid")
        if os.path.exists(pid_path):
            os.remove(pid_path)


if __name__ == "__main__":
    main()
