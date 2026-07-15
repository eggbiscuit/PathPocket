FROM python:3.12-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Enable the proprietary readers (x86_64 only). Off by default so arm/dev builds
# stay lean and fast; turn on for production with:
#   docker build --build-arg ENABLE_SDPC=1 --build-arg ENABLE_KFB=1 ...
ARG ENABLE_SDPC=0
ARG ENABLE_KFB=0

COPY requirements.txt .
RUN pip install --no-cache-dir --retries 10 --timeout 120 -r requirements.txt

# sdpc extras: its native libDecodeSdpc.so needs libgomp1 (OpenMP); libjpeg.so.8
# + ffmpeg libs ship bundled in the wheel (see LD_LIBRARY_PATH). opensdpc declares
# the GUI opencv-python, so we install it --no-deps and supply headless opencv via
# requirements-sdpc.txt to avoid pulling X11 libraries.
COPY requirements-sdpc.txt .
RUN if [ "$ENABLE_SDPC" = "1" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends libgomp1 \
        && rm -rf /var/lib/apt/lists/* \
        && pip install --no-cache-dir --retries 10 --timeout 120 \
             numpy Pillow opencv-python-headless==4.11.0.86 \
        && pip install --no-cache-dir --retries 10 --timeout 120 --no-deps \
             opensdpc==1.0.0 ; \
    fi

# kfb reader via ASlide (installed from git). It bundles its own native libs
# (libkfbslide.so + libjpeg.so.9 + libcurl.so + its OpenCV .so set) under the
# package, and pins numpy<2 — acceptable in this optional x86_64 image. git is
# needed for the VCS install.
COPY requirements-kfb.txt .
RUN if [ "$ENABLE_KFB" = "1" ]; then \
        apt-get update \
        && apt-get install -y --no-install-recommends git libgomp1 \
        && rm -rf /var/lib/apt/lists/* \
        && pip install --no-cache-dir --retries 10 --timeout 120 -r requirements-kfb.txt ; \
    fi

# Native lib search paths for the optional readers. Harmless when a reader isn't
# installed (the dir just won't exist). ASlide loads its kfb/opencv .so from the
# package's lib dirs.
ENV LD_LIBRARY_PATH=/usr/local/lib/python3.12/site-packages/opensdpc/LINUX:/usr/local/lib/python3.12/site-packages/opensdpc/LINUX/ffmpeg:/usr/local/lib/python3.12/site-packages/opensdpc/LINUX/jpeg:/usr/local/lib/python3.12/site-packages/Aslide/kfb/lib:/usr/local/lib/python3.12/site-packages/Aslide/opencv/lib

COPY app ./app

EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
