import httpx2


class SupabaseStorageStore:
    """Writes redacted training images to a private Supabase Storage bucket (service role only)."""

    def __init__(
        self, supabase_url: str, service_key: str, bucket: str = "training-examples", client=None
    ):
        self._base = f"{supabase_url.rstrip('/')}/storage/v1/object/{bucket}"
        self._headers = {"Authorization": f"Bearer {service_key}", "apikey": service_key}
        self._client = client or httpx2.Client(timeout=30)

    def put(self, path: str, data: bytes) -> None:
        r = self._client.post(
            f"{self._base}/{path}",
            content=data,
            headers={**self._headers, "Content-Type": "image/jpeg"},
        )
        r.raise_for_status()
