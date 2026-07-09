"""LRU cache of open OpenSlide handles + their DeepZoom generators.

Opening a slide and building a DeepZoomGenerator is expensive (seconds for large
pyramids), so we keep a bounded pool keyed by slide_id and reuse it across the
many tile requests of a single pan/zoom session. OpenSlide's read_region is
thread-safe per handle, so one cached handle can serve concurrent tile reads.
"""

import threading
from collections import OrderedDict

import openslide
from openslide.deepzoom import DeepZoomGenerator

from .config import get_settings

_settings = get_settings()


class CacheEntry:
    __slots__ = ("slide", "dzg", "owner_id")

    def __init__(self, slide: openslide.OpenSlide, dzg: DeepZoomGenerator, owner_id: str):
        self.slide = slide
        self.dzg = dzg
        self.owner_id = owner_id


_cache: "OrderedDict[str, CacheEntry]" = OrderedDict()
_lock = threading.Lock()


def peek(slide_id: str) -> CacheEntry | None:
    """Fast, DB-free lookup for the tile hot path. Returns None on miss."""
    with _lock:
        entry = _cache.get(slide_id)
        if entry is not None:
            _cache.move_to_end(slide_id)
        return entry


def get_entry(slide_id: str, path: str, owner_id: str) -> CacheEntry:
    """Returns a cached entry, opening the slide on miss. Blocking — call in a
    threadpool from async code."""
    hit = peek(slide_id)
    if hit is not None:
        return hit
    # Open outside the lock (slow); tolerate a rare double-open race.
    slide = openslide.OpenSlide(path)
    dzg = DeepZoomGenerator(
        slide,
        tile_size=_settings.wsi_tile_size,
        overlap=_settings.wsi_tile_overlap,
        limit_bounds=True,
    )
    entry = CacheEntry(slide, dzg, owner_id)
    with _lock:
        _cache[slide_id] = entry
        _cache.move_to_end(slide_id)
        while len(_cache) > _settings.wsi_cache_size:
            _, evicted = _cache.popitem(last=False)
            try:
                evicted.slide.close()
            except Exception:
                pass
    return entry


def drop(slide_id: str) -> None:
    """Evict + close a handle (called on delete)."""
    with _lock:
        entry = _cache.pop(slide_id, None)
    if entry is not None:
        try:
            entry.slide.close()
        except Exception:
            pass
