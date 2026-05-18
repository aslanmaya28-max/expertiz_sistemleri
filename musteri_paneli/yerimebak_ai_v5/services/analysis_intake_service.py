from urllib.parse import urlparse


class AnalysisIntakeService:
    allowed_sources = {"mobile_share", "manual_paste", "chrome_extension"}

    def build_url_intake(self, url: str, source: str) -> dict:
        normalized_url = url.strip()
        parsed_url = urlparse(normalized_url)

        if parsed_url.scheme not in {"http", "https"} or not parsed_url.netloc:
            raise ValueError("Gecersiz URL")
        if source not in self.allowed_sources:
            raise ValueError("Gecersiz kaynak")

        return {"url": normalized_url, "source": source, "status": "queued"}
