"""Slide opening abstraction over OpenSlide + the proprietary sdpc format.

OpenSlide reads .svs/.tiff/.ndpi/etc. The Sqray .sdpc format needs the vendor's
`opensdpc` library, which ships an x86_64-only native lib — so it may be
unavailable (e.g. on arm dev machines). `sdpc_available()` probes that at import
time; callers gate on it and fall back to "unsupported" when it's False.

SdpcSlide adapts an opensdpc handle to the subset of the OpenSlide interface that
`openslide.deepzoom.DeepZoomGenerator` and our tile/thumbnail code rely on:
`dimensions`, `properties`, `level_dimensions`, `level_downsamples`,
`level_count`, `get_best_level_for_downsample`, `read_region` (RGBA), and
`get_thumbnail`.
"""

import os

import openslide
from PIL import Image

_SDPC_EXT = ".sdpc"
_OPENSLIDE_EXT = {".svs", ".tif", ".tiff", ".ndpi", ".scn", ".mrxs", ".vms", ".vmu", ".bif"}

# Probe opensdpc once. The native lib load happens at import, so a failure here
# (wrong arch, missing .so deps) means sdpc is simply unavailable.
try:
    import opensdpc  # noqa: F401

    _SDPC_AVAILABLE = True
    _SDPC_IMPORT_ERROR = ""
except Exception as exc:  # ImportError, OSError (dlopen), etc.
    _SDPC_AVAILABLE = False
    _SDPC_IMPORT_ERROR = f"{type(exc).__name__}: {exc}"


def sdpc_available() -> bool:
    return _SDPC_AVAILABLE


def sdpc_import_error() -> str:
    return _SDPC_IMPORT_ERROR


class SdpcSlide:
    """Adapts an opensdpc handle to the OpenSlide interface DeepZoomGenerator uses.

    The underlying OldSdpc already provides level_count/level_dimensions/
    level_downsamples/get_best_level_for_downsample/read_region/close; we add the
    two attributes DeepZoom also reads (`dimensions`, `properties`), convert tiles
    to RGBA (opensdpc returns RGB, but DeepZoom uses the tile's alpha as a
    composite mask), and synthesize `get_thumbnail`.
    """

    def __init__(self, path: str):
        self._sdpc = opensdpc.OpenSdpc(path)

    @property
    def level_count(self) -> int:
        return self._sdpc.level_count

    @property
    def level_dimensions(self):
        return tuple(tuple(d) for d in self._sdpc.level_dimensions)

    @property
    def level_downsamples(self):
        return tuple(self._sdpc.level_downsamples)

    @property
    def dimensions(self):
        return self.level_dimensions[0]

    @property
    def properties(self) -> dict:
        # sdpc exposes no bounds/background props; DeepZoom has defaults for all
        # the keys it reads, so an empty mapping is correct.
        return {}

    def get_best_level_for_downsample(self, downsample: float) -> int:
        return self._sdpc.get_best_level_for_downsample(downsample)

    def read_region(self, location, level, size) -> Image.Image:
        img = self._sdpc.read_region(location, level, size)
        if img.mode != "RGBA":
            img = img.convert("RGBA")
        return img

    def get_thumbnail(self, size) -> Image.Image:
        # Render from the smallest (highest-index) level, then fit into `size`.
        top = self.level_count - 1
        dims = self.level_dimensions[top]
        img = self._sdpc.read_region((0, 0), top, dims).convert("RGB")
        img.thumbnail(size, getattr(Image, "Resampling", Image).LANCZOS)
        return img

    def close(self) -> None:
        try:
            self._sdpc.close()
        except Exception:
            pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


def can_open(ext: str) -> bool:
    """Whether the given file extension is supported in this environment."""
    ext = ext.lower()
    if ext in _OPENSLIDE_EXT:
        return True
    if ext == _SDPC_EXT:
        return _SDPC_AVAILABLE
    return False


def open_slide(path: str):
    """Opens a slide with the right backend. Blocking — call in a threadpool."""
    ext = os.path.splitext(path)[1].lower()
    if ext == _SDPC_EXT:
        if not _SDPC_AVAILABLE:
            raise RuntimeError("sdpc backend unavailable in this environment")
        return SdpcSlide(path)
    return openslide.OpenSlide(path)


def probe(path: str) -> tuple[str, tuple[int, int]]:
    """Detect format + level-0 dimensions. Blocking — call in a threadpool."""
    ext = os.path.splitext(path)[1].lower()
    if ext == _SDPC_EXT:
        slide = open_slide(path)
        try:
            return "sdpc", slide.dimensions
        finally:
            slide.close()
    fmt = openslide.OpenSlide.detect_format(path)
    if fmt is None:
        raise ValueError("openslide cannot read this file")
    with openslide.OpenSlide(path) as s:
        return fmt, s.dimensions
