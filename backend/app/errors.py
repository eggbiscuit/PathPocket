from fastapi import HTTPException


def app_error(status_code: int, code: str, message: str) -> HTTPException:
    """Builds an HTTPException whose body is `{"detail": {code, message}}`.

    The Flutter client switches on `detail.code` to drive different UI
    (pending-approval screen, email-not-verified hint, etc.).
    """
    return HTTPException(
        status_code=status_code, detail={"code": code, "message": message}
    )
