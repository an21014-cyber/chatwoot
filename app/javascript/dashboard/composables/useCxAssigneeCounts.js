// CX POC 커스텀: 사이드바 "담당자" 목록과 담당자 화면 탭의 건수.
// 서버(Api::V1::Accounts::CxAssigneeCountsController)가 담당자별로 한 번에 집계해 준다. 앱 전체에서 하나만 돌리고(30초 간격 +
// 창으로 돌아올 때) 여러 곳에서 같은 값을 공유한다.
import { ref } from 'vue';

const counts = ref({});
let started = false;

async function refreshCounts(accountId) {
  if (!accountId) return;
  try {
    const { data } = await window.axios.get(
      `/api/v1/accounts/${accountId}/cx_assignee_counts`
    );
    counts.value = data.counts || {};
  } catch (e) {
    // 건수는 보조 정보라 실패해도 화면은 그대로 둔다
  }
}

export function useCxAssigneeCounts(accountId) {
  if (!started) {
    started = true;
    refreshCounts(accountId.value);
    setInterval(() => refreshCounts(accountId.value), 30000);
    window.addEventListener('focus', () => refreshCounts(accountId.value));
  }
  return { counts, refresh: () => refreshCounts(accountId.value) };
}
