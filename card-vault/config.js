// 카드 보관소 설정 — Supabase 프로젝트를 만든 뒤 두 값을 채워 넣으세요.
// Supabase 대시보드 → Project Settings → API 에서 복사 (anon key는 공개돼도 되는 키예요. service_role 키는 절대 넣지 마세요)
window.VAULT_CONFIG = {
  supabaseUrl: '',          // 예: 'https://abcdefgh.supabase.co'
  supabaseAnonKey: '',      // 예: 'eyJhbGciOi...'
  // 입고 카드를 보낼 곳 (운영자 주소)
  shipTo: '보낼 곳: (운영자 주소를 config.js에 적어주세요)',
  // 포인트 충전 안내 (MVP는 운영자가 입금 확인 후 수동 충전)
  depositInfo: '충전: (입금 계좌를 config.js에 적어주세요) — 입금자명에 닉네임을 적어주세요.'
};
