"""Public privacy policy and terms pages."""

from fastapi.testclient import TestClient

from app.api.legal import markdown_to_html
from app.main import create_app


def test_privacy_policy_is_public_html():
    client = TestClient(create_app())
    for path, marker in [
        ("/privacy", "গোপনীয়তা নীতি"),
        ("/privacy/en", "Privacy"),
        ("/terms", "Terms"),
    ]:
        r = client.get(path)  # no sign-in: it must be readable by anyone, e.g. Google Play
        assert r.status_code == 200, path
        assert r.headers["content-type"].startswith("text/html")
        assert marker in r.text
        assert "<table>" in r.text or path == "/terms"


def test_markdown_is_converted_and_html_is_escaped():
    out = markdown_to_html(
        "# Title\n\nSome **bold** and [a link](https://example.com).\n\n"
        "| a | b |\n|---|---|\n| 1 | <script>x</script> |\n\n> note\n\n- one\n- two\n"
    )
    assert "<h1>Title</h1>" in out
    assert "<strong>bold</strong>" in out
    assert '<a href="https://example.com" rel="noopener">a link</a>' in out
    assert "<td>&lt;script&gt;x&lt;/script&gt;</td>" in out
    assert "<blockquote>note</blockquote>" in out
    assert "<ul><li>one</li><li>two</li></ul>" in out
