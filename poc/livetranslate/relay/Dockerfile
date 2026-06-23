FROM python:3.11-slim

WORKDIR /app

# 의존성 먼저 설치(레이어 캐시).
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

EXPOSE 8080

# 프로덕션 구동: uvicorn 단일 워커(WebSocket 상태 유지 세션이므로 워커 확장 시
# 세션 친화성/스케일 전략 별도 고려).
# 클라우드 플랫폼이 주입하는 $PORT를 우선 사용(없으면 8080). 셸 형태라 환경변수 확장됨.
CMD uvicorn main:app --host 0.0.0.0 --port ${PORT:-8080}
