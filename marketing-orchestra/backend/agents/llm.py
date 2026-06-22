"""
LLM 추상화 + 모델 티어링 + 크레딧 계측 (orchestrator §6·§7).

설계 원칙(저렴한 API):
- 모델 티어링: 라우팅=저가 Haiku, 심층생성=Sonnet (Opus는 업그레이드 옵션)
- 계측=과금: 호출 토큰 → 원가(USD) → 크레딧 환산 (비용과 매출을 한 단위로)
- 무키/무네트워크에서도 동작: StubProvider(결정적) ↔ AnthropicProvider(실연동) 교체

모델 ID·단가는 Anthropic 공식(2026-06) 기준. 환경변수로 티어 오버라이드 가능.
"""
import math
import os
from dataclasses import dataclass

# 모델별 (입력, 출력) USD / 1M tokens
PRICING = {
    "claude-haiku-4-5": (1.0, 5.0),
    "claude-sonnet-4-6": (3.0, 15.0),
    "claude-opus-4-8": (5.0, 25.0),
}

# 티어: 저렴한 API 원칙 — 라우터는 최저가, 생성은 중간가 기본
ROUTER_MODEL = os.environ.get("GEO_ROUTER_MODEL", "claude-haiku-4-5")
GENERATOR_MODEL = os.environ.get("GEO_GENERATOR_MODEL", "claude-sonnet-4-6")

# 1 크레딧이 대응하는 '원가' USD. 판매가는 이 위에 마진을 얹어 책정(§7).
CREDIT_COST_USD = float(os.environ.get("GEO_CREDIT_COST_USD", "0.01"))


@dataclass
class Usage:
    model: str = ""
    input_tokens: int = 0
    output_tokens: int = 0
    cache_read_tokens: int = 0

    def cost_usd(self) -> float:
        pin, pout = PRICING.get(self.model, (3.0, 15.0))
        # 캐시 읽기는 ~0.1배로 과금
        billable_in = self.input_tokens + self.cache_read_tokens * 0.1
        return (billable_in * pin + self.output_tokens * pout) / 1_000_000


@dataclass
class Meter:
    """호출 누적 계측 → 크레딧 환산(계측=과금)."""
    calls: list[Usage]

    def __init__(self):
        self.calls = []

    def add(self, u: Usage):
        self.calls.append(u)

    def total_cost_usd(self) -> float:
        return sum(u.cost_usd() for u in self.calls)

    def credits(self) -> int:
        # 비용을 크레딧으로 올림 환산 → 항상 원가 ≤ 청구 (마진 보호)
        return max(1, math.ceil(self.total_cost_usd() / CREDIT_COST_USD))

    def breakdown(self) -> list[dict]:
        return [
            {"model": u.model, "in": u.input_tokens, "out": u.output_tokens,
             "cost_usd": round(u.cost_usd(), 6)}
            for u in self.calls
        ]


class StubProvider:
    """무키/무네트워크용 결정적 제공자. 입력을 그대로 반환(생성은 호출부 템플릿)."""

    name = "stub"

    def complete(self, *, model: str, system: str, prompt: str, max_tokens: int = 800) -> tuple[str, Usage]:
        # 토큰 추정(문자/4) — 계측 파이프라인을 실연동과 동일하게 태우기 위함
        in_tok = (len(system) + len(prompt)) // 4
        out_tok = min(max_tokens, max(40, len(prompt) // 8))
        # 스텁은 phrasing을 하지 않고, 호출부가 만든 grounded 텍스트(prompt 말미)를 통과
        return prompt, Usage(model=model, input_tokens=in_tok, output_tokens=out_tok)


class AnthropicProvider:
    """실제 Claude 연동. ANTHROPIC_API_KEY + anthropic SDK + 네트워크 필요."""

    name = "anthropic"

    def complete(self, *, model: str, system: str, prompt: str, max_tokens: int = 800) -> tuple[str, Usage]:
        import anthropic  # 지연 임포트(미설치 환경 보호)

        client = anthropic.Anthropic()
        resp = client.messages.create(
            model=model,
            max_tokens=max_tokens,
            system=system,
            messages=[{"role": "user", "content": prompt}],
        )
        text = "".join(b.text for b in resp.content if b.type == "text")
        u = resp.usage
        return text, Usage(
            model=model,
            input_tokens=u.input_tokens,
            output_tokens=u.output_tokens,
            cache_read_tokens=getattr(u, "cache_read_input_tokens", 0) or 0,
        )


def get_provider():
    """키+SDK 있으면 실연동, 아니면 스텁. 결정은 런타임 환경에 위임(투명 보고)."""
    if os.environ.get("ANTHROPIC_API_KEY"):
        try:
            import anthropic  # noqa: F401
            return AnthropicProvider()
        except ImportError:
            pass
    return StubProvider()
