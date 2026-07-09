import importlib.util
import io

import pytest

from tests.conftest import admin_token

# OpenSlide's native lib may be absent in some CI images; skip the whole module.
_HAS_OPENSLIDE = importlib.util.find_spec("openslide") is not None
_HAS_TIFFFILE = importlib.util.find_spec("tifffile") is not None
pytestmark = pytest.mark.skipif(
    not (_HAS_OPENSLIDE and _HAS_TIFFFILE),
    reason="requires openslide + tifffile",
)


def _tiled_tiff_bytes() -> bytes:
    """A small tiled TIFF that OpenSlide reads as generic-tiff."""
    import numpy as np
    import tifffile

    arr = (np.random.rand(1500, 2000, 3) * 255).astype("uint8")
    buf = io.BytesIO()
    tifffile.imwrite(buf, arr, tile=(256, 256), photometric="rgb", compression="deflate")
    return buf.getvalue()


async def _upload(client, token) -> dict:
    resp = await client.post(
        "/wsi/slides",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("sample.tiff", _tiled_tiff_bytes(), "image/tiff")},
    )
    assert resp.status_code == 201, resp.text
    return resp.json()


@pytest.mark.asyncio
async def test_upload_probes_and_marks_ready(client):
    token = await admin_token(client)
    slide = await _upload(client, token)
    assert slide["status"] == "ready"
    assert slide["fmt"] == "generic-tiff"
    assert slide["width"] == 2000 and slide["height"] == 1500


@pytest.mark.asyncio
async def test_reject_vendor_format(client):
    token = await admin_token(client)
    resp = await client.post(
        "/wsi/slides",
        headers={"Authorization": f"Bearer {token}"},
        files={"file": ("scan.kfb", b"not-a-real-slide", "application/octet-stream")},
    )
    assert resp.status_code == 415
    assert resp.json()["detail"]["code"] == "UNSUPPORTED_FORMAT"


@pytest.mark.asyncio
async def test_dzi_and_tile(client):
    token = await admin_token(client)
    slide = await _upload(client, token)
    sid = slide["id"]
    headers = {"Authorization": f"Bearer {token}"}

    dzi = await client.get(f"/wsi/slides/{sid}/dzi", headers=headers)
    assert dzi.status_code == 200
    assert 'Width="2000"' in dzi.text and 'Height="1500"' in dzi.text

    tile = await client.get(f"/wsi/slides/{sid}/tiles/0/0_0.jpeg", headers=headers)
    assert tile.status_code == 200
    assert tile.headers["content-type"] == "image/jpeg"


@pytest.mark.asyncio
async def test_tile_requires_auth(client):
    token = await admin_token(client)
    slide = await _upload(client, token)
    resp = await client.get(f"/wsi/slides/{slide['id']}/tiles/0/0_0.jpeg")
    assert resp.status_code == 401


@pytest.mark.asyncio
async def test_list_and_delete(client):
    token = await admin_token(client)
    slide = await _upload(client, token)
    headers = {"Authorization": f"Bearer {token}"}

    listed = await client.get("/wsi/slides", headers=headers)
    assert listed.status_code == 200
    assert any(s["id"] == slide["id"] for s in listed.json())

    deleted = await client.delete(f"/wsi/slides/{slide['id']}", headers=headers)
    assert deleted.status_code == 204

    after = await client.get("/wsi/slides", headers=headers)
    assert all(s["id"] != slide["id"] for s in after.json())
