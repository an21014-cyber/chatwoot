// CX POC 커스텀: 봇 관리 화면(iframe)에 넘길 로그인 연동 토큰.
// Chatwoot에 로그인한 사용자 기준으로 서버(Api::V1::CxSsoController)가 서명해 주고, 8시간 유효하다.
// 토큰은 iframe 주소의 #해시(cx_token=...)로 넘긴다 - 해시는 서버로 전송되지 않아 접속 로그에 남지 않는다.
const REFRESH_MARGIN_MS = 10 * 60 * 1000;
let cache = { token: '', accountId: '', expiresAt: 0 };

export async function getCxToken(accountId) {
  const now = Date.now();
  if (
    cache.token &&
    cache.accountId === String(accountId) &&
    cache.expiresAt - now > REFRESH_MARGIN_MS
  ) {
    return cache.token;
  }
  const { data } = await window.axios.get('/api/v1/cx_sso/token', {
    params: { account_id: accountId },
  });
  cache = {
    token: data.token,
    accountId: String(accountId),
    expiresAt: data.expires_at * 1000,
  };
  return cache.token;
}

export function withCxToken(url, token) {
  return token ? `${url}#cx_token=${token}` : url;
}
