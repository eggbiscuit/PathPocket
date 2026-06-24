from app.security import create_verify_token

from .conftest import admin_token


async def test_admin_endpoints_require_auth(client):
    assert (await client.get("/admin/users")).status_code == 401


async def test_non_admin_forbidden(client):
    # Register + verify + (manually approve via admin) so the user can log in,
    # then confirm they still can't reach admin endpoints.
    resp = await client.post(
        "/auth/register",
        json={"email": "user@test.dev", "password": "secret123"},
    )
    user_id = resp.json()["user"]["id"]
    await client.get(f"/auth/verify-email?token={create_verify_token(user_id)}")

    atoken = await admin_token(client)
    await client.post(
        f"/admin/users/{user_id}/approve",
        headers={"Authorization": f"Bearer {atoken}"},
    )
    login = await client.post(
        "/auth/login", json={"email": "user@test.dev", "password": "secret123"}
    )
    utoken = login.json()["access_token"]

    forbidden = await client.get(
        "/admin/users", headers={"Authorization": f"Bearer {utoken}"}
    )
    assert forbidden.status_code == 403
    assert forbidden.json()["detail"]["code"] == "FORBIDDEN"


async def test_list_pending_users(client):
    await client.post(
        "/auth/register", json={"email": "a@test.dev", "password": "secret123"}
    )
    await client.post(
        "/auth/register", json={"email": "b@test.dev", "password": "secret123"}
    )

    token = await admin_token(client)
    resp = await client.get(
        "/admin/users?status=pending",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200
    emails = {u["email"] for u in resp.json()}
    assert {"a@test.dev", "b@test.dev"} <= emails
    # The approved admin must not appear in the pending list.
    assert all(u["status"] == "pending" for u in resp.json())
