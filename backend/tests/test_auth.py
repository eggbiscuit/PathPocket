from app.security import create_verify_token

from .conftest import admin_token


async def register(client, email="doc@test.dev", password="secret123"):
    return await client.post(
        "/auth/register",
        json={"email": email, "password": password, "display_name": "Doc"},
    )


async def test_register_rejects_invalid_email(client):
    resp = await client.post(
        "/auth/register", json={"email": "not-an-email", "password": "secret123"}
    )
    assert resp.status_code == 422


async def test_register_rejects_short_password(client):
    resp = await client.post(
        "/auth/register", json={"email": "x@test.dev", "password": "123"}
    )
    assert resp.status_code == 422


async def test_register_then_duplicate_conflicts(client):
    assert (await register(client)).status_code == 201
    dup = await register(client)
    assert dup.status_code == 409
    assert dup.json()["detail"]["code"] == "EMAIL_EXISTS"


async def test_login_blocked_until_verified_and_approved(client):
    resp = await register(client)
    user_id = resp.json()["user"]["id"]

    # Not verified yet -> EMAIL_NOT_VERIFIED
    r1 = await client.post(
        "/auth/login", json={"email": "doc@test.dev", "password": "secret123"}
    )
    assert r1.status_code == 403
    assert r1.json()["detail"]["code"] == "EMAIL_NOT_VERIFIED"

    # Verify email -> still pending approval
    v = await client.get(f"/auth/verify-email?token={create_verify_token(user_id)}")
    assert v.status_code == 200
    r2 = await client.post(
        "/auth/login", json={"email": "doc@test.dev", "password": "secret123"}
    )
    assert r2.status_code == 403
    assert r2.json()["detail"]["code"] == "PENDING_APPROVAL"


async def test_wrong_password(client):
    await register(client)
    r = await client.post(
        "/auth/login", json={"email": "doc@test.dev", "password": "wrongpass"}
    )
    assert r.status_code == 401
    assert r.json()["detail"]["code"] == "INVALID_CREDENTIALS"


async def test_full_flow_register_verify_approve_login(client):
    resp = await register(client)
    user_id = resp.json()["user"]["id"]
    await client.get(f"/auth/verify-email?token={create_verify_token(user_id)}")

    token = await admin_token(client)
    approve = await client.post(
        f"/admin/users/{user_id}/approve",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert approve.status_code == 200
    assert approve.json()["status"] == "approved"

    login = await client.post(
        "/auth/login", json={"email": "doc@test.dev", "password": "secret123"}
    )
    assert login.status_code == 200
    body = login.json()
    assert body["access_token"]
    assert body["user"]["email"] == "doc@test.dev"

    me = await client.get(
        "/auth/me", headers={"Authorization": f"Bearer {body['access_token']}"}
    )
    assert me.status_code == 200
    assert me.json()["role"] == "user"


async def test_rejected_user_cannot_login(client):
    resp = await register(client)
    user_id = resp.json()["user"]["id"]
    await client.get(f"/auth/verify-email?token={create_verify_token(user_id)}")

    token = await admin_token(client)
    await client.post(
        f"/admin/users/{user_id}/reject",
        headers={"Authorization": f"Bearer {token}"},
    )
    login = await client.post(
        "/auth/login", json={"email": "doc@test.dev", "password": "secret123"}
    )
    assert login.status_code == 403
    assert login.json()["detail"]["code"] == "REJECTED"
