"""Apify giris noktasi: girdiyi okur, ilanlari toplar, dataset'e yazar."""
from apify import Actor

from .collect import collect


async def main() -> None:
    async with Actor:
        inp = await Actor.get_input() or {}
        Actor.log.info("YerimeBak arac verisi: mod=%s", inp.get("mode"))
        try:
            items = await collect(inp)
        except ValueError as exc:
            await Actor.fail(status_message=str(exc))
            return
        for item in items:
            await Actor.push_data(item)
        await Actor.set_value("OZET", {"mode": inp.get("mode"), "count": len(items)})
        await Actor.set_status_message(f"{len(items)} ilan toplandi")
