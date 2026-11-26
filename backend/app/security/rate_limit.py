"""In-process sliding-window rate limiting.

Good for a single server instance. With several instances behind a load balancer, replace the
storage with a shared one (e.g. Redis) behind the same interface.
"""

import threading
import time
from collections import defaultdict, deque
from collections.abc import Callable


class RateLimited(Exception):
    def __init__(self, retry_after: int):
        super().__init__(f"Retry after {retry_after}s")
        self.retry_after = retry_after


class SlidingWindowLimiter:
    def __init__(
        self, limits: list[tuple[int, float]], clock: Callable[[], float] = time.monotonic
    ):
        """`limits`: (max requests, window seconds) pairs, all of which must hold."""
        self._limits = sorted(limits, key=lambda x: x[1])
        self._longest = self._limits[-1][1]
        self._clock = clock
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def check(self, key: str) -> None:
        """Records a request for `key`, or raises RateLimited without recording it."""
        now = self._clock()
        with self._lock:
            hits = self._hits[key]
            while hits and hits[0] <= now - self._longest:
                hits.popleft()
            for limit, window in self._limits:
                recent = [t for t in hits if t > now - window]
                if len(recent) >= limit:
                    retry = int(recent[0] + window - now) + 1
                    raise RateLimited(retry)
            hits.append(now)
