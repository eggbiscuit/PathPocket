import io
import os

from fastapi import APIRouter, Depends, File, Response, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from starlette.concurrency import run_in_threadpool

from .. import slide_backend, wsi_cache
from ..config import get_settings
from ..database import get_session
from ..errors import app_error
from ..models import Slide, SlideStatus, User
from ..schemas import SlideOut
from ..security import get_current_user, get_current_user_id

router = APIRouter(prefix="/wsi", tags=["wsi"])
_settings = get_settings()

# .kfb (江丰) has no open reader yet; .sdpc (生强) needs the opensdpc native lib,
# which is x86_64-only — accepted only when that backend loaded successfully.
_KFB_EXT = ".kfb"
_SDPC_EXT = ".sdpc"


async def _owned_slide(session: AsyncSession, slide_id: str, user_id: str) -> Slide:
    slide = await session.get(Slide, slide_id)
    if slide is None:
        raise app_error(404, "SLIDE_NOT_FOUND", "切片不存在")
    if slide.user_id != user_id:
        raise app_error(403, "FORBIDDEN", "无权访问该切片")
    return slide


@router.post("/slides", response_model=SlideOut, status_code=201)
async def upload_slide(
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    name = file.filename or "upload"
    ext = os.path.splitext(name)[1].lower()
    if ext == _KFB_EXT:
        raise app_error(
            415,
            "UNSUPPORTED_FORMAT",
            "江丰 KFBIO 格式（.kfb）暂不支持，后续将通过转码支持。当前请上传 .svs / .tiff / .sdpc。",
        )
    if ext == _SDPC_EXT and not slide_backend.sdpc_available():
        raise app_error(
            415,
            "UNSUPPORTED_FORMAT",
            "当前服务未启用 .sdpc 支持（需 x86_64 环境）。请上传 .svs / .tiff。",
        )
    if not slide_backend.can_open(ext):
        raise app_error(415, "UNSUPPORTED_FORMAT", "不支持的切片格式")

    slide = Slide(
        user_id=user.id,
        original_filename=name,
        stored_path="",
        fmt="",
        status=SlideStatus.uploading,
    )
    session.add(slide)
    await session.commit()
    await session.refresh(slide)

    slide_dir = os.path.join(_settings.wsi_storage_dir, user.id)
    os.makedirs(slide_dir, exist_ok=True)
    path = os.path.join(slide_dir, f"{slide.id}{ext}")

    written = 0
    with open(path, "wb") as out:
        while chunk := await file.read(1024 * 1024):
            written += len(chunk)
            if written > _settings.wsi_max_upload_bytes:
                out.close()
                os.remove(path)
                await session.delete(slide)
                await session.commit()
                raise app_error(413, "FILE_TOO_LARGE", "文件超过大小上限")
            out.write(chunk)

    try:
        fmt, (w, h) = await run_in_threadpool(slide_backend.probe, path)
    except Exception:
        slide.status = SlideStatus.failed
        await session.commit()
        try:
            os.remove(path)
        except FileNotFoundError:
            pass
        raise app_error(422, "UNREADABLE_SLIDE", "无法解析该切片文件，可能已损坏或非标准格式")

    slide.stored_path = path
    slide.fmt = fmt
    slide.file_size = written
    slide.width = w
    slide.height = h
    slide.status = SlideStatus.ready
    await session.commit()
    await session.refresh(slide)
    return SlideOut.model_validate(slide)


@router.get("/slides", response_model=list[SlideOut])
async def list_slides(
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    rows = await session.execute(
        select(Slide)
        .where(Slide.user_id == user.id, Slide.status != SlideStatus.failed)
        .order_by(Slide.created_at.desc())
    )
    return [SlideOut.model_validate(s) for s in rows.scalars().all()]


@router.get("/slides/{slide_id}/dzi")
async def slide_dzi(
    slide_id: str,
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_session),
):
    slide = await _owned_slide(session, slide_id, user_id)
    entry = await run_in_threadpool(
        wsi_cache.get_entry, slide.id, slide.stored_path, user_id
    )
    xml = entry.dzg.get_dzi("jpeg")
    return Response(content=xml, media_type="application/xml")


@router.get("/slides/{slide_id}/tiles/{level}/{col}_{row}.jpeg")
async def slide_tile(
    slide_id: str,
    level: int,
    col: int,
    row: int,
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_session),
):
    entry = wsi_cache.peek(slide_id)
    if entry is None or entry.owner_id != user_id:
        slide = await _owned_slide(session, slide_id, user_id)
        entry = await run_in_threadpool(
            wsi_cache.get_entry, slide.id, slide.stored_path, user_id
        )
    if entry.owner_id != user_id:
        raise app_error(403, "FORBIDDEN", "无权访问该切片")

    def _render() -> bytes:
        img = entry.dzg.get_tile(level, (col, row))
        buf = io.BytesIO()
        img.save(buf, "jpeg", quality=80)
        return buf.getvalue()

    try:
        data = await run_in_threadpool(_render)
    except (ValueError, IndexError):
        raise app_error(404, "TILE_OUT_OF_RANGE", "瓦片坐标越界")
    return Response(
        content=data,
        media_type="image/jpeg",
        headers={"Cache-Control": "private, max-age=3600"},
    )


@router.get("/slides/{slide_id}/thumbnail")
async def slide_thumbnail(
    slide_id: str,
    user_id: str = Depends(get_current_user_id),
    session: AsyncSession = Depends(get_session),
):
    slide = await _owned_slide(session, slide_id, user_id)

    def _thumb() -> bytes:
        s = slide_backend.open_slide(slide.stored_path)
        try:
            img = s.get_thumbnail((256, 256))
            buf = io.BytesIO()
            img.convert("RGB").save(buf, "jpeg", quality=80)
            return buf.getvalue()
        finally:
            s.close()

    data = await run_in_threadpool(_thumb)
    return Response(
        content=data,
        media_type="image/jpeg",
        headers={"Cache-Control": "private, max-age=86400"},
    )


@router.delete("/slides/{slide_id}", status_code=204)
async def delete_slide(
    slide_id: str,
    user: User = Depends(get_current_user),
    session: AsyncSession = Depends(get_session),
):
    slide = await _owned_slide(session, slide_id, user.id)
    wsi_cache.drop(slide.id)
    if slide.stored_path:
        try:
            os.remove(slide.stored_path)
        except FileNotFoundError:
            pass
    await session.delete(slide)
    await session.commit()
    return Response(status_code=204)
