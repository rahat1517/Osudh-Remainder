"""Verifies Supabase access tokens (JWTs) on API requests.

Supabase projects sign tokens either with asymmetric signing keys (ES256/RS256, public keys
published at <project>/auth/v1/.well-known/jwks.json) or, in older projects, with a shared
HS256 secret.
Both are supported; the token's `alg` header decides which key is used.
"""

from dataclasses import dataclass

import jwt

AUDIENCE = "authenticated"


class AuthError(Exception):
    def __init__(self, code: str, message: str):
        super().__init__(message)
        self.code = code  # auth_required, auth_invalid
        self.message = message


@dataclass(frozen=True)
class User:
    id: str
    role: str = "authenticated"

    @property
    def is_anonymous(self) -> bool:
        return self.id == ANONYMOUS.id


ANONYMOUS = User(id="anonymous", role="anon")


class TokenVerifier:
    def __init__(
        self,
        *,
        jwks_url: str | None = None,
        jwt_secret: str | None = None,
        issuer: str | None = None,
        jwks_client: jwt.PyJWKClient | None = None,
    ):
        if not (jwks_url or jwt_secret or jwks_client):
            raise ValueError("TokenVerifier needs a JWKS URL or a JWT secret")
        self._secret = jwt_secret
        self._issuer = issuer
        self._jwks = jwks_client or (
            jwt.PyJWKClient(jwks_url, cache_keys=True, lifespan=600) if jwks_url else None
        )

    def verify(self, token: str) -> User:
        try:
            alg = jwt.get_unverified_header(token).get("alg", "")
            if alg.startswith("HS"):
                if not self._secret:
                    raise AuthError("auth_invalid", "Symmetric tokens are not accepted")
                key: object = self._secret
                algorithms = ["HS256"]
            else:
                if self._jwks is None:
                    raise AuthError("auth_invalid", "Asymmetric tokens are not accepted")
                key = self._jwks.get_signing_key_from_jwt(token).key
                algorithms = ["ES256", "RS256"]
            claims = jwt.decode(
                token,
                key,
                algorithms=algorithms,
                audience=AUDIENCE,
                issuer=self._issuer,
                options={"require": ["exp", "sub"], "verify_iss": self._issuer is not None},
            )
        except AuthError:
            raise
        except jwt.ExpiredSignatureError as e:
            raise AuthError("auth_invalid", "Token expired") from e
        except (jwt.PyJWTError, ValueError) as e:
            raise AuthError("auth_invalid", "Invalid token") from e
        return User(id=claims["sub"], role=claims.get("role", "authenticated"))
