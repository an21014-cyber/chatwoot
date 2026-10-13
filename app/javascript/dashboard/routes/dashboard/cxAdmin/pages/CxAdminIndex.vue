<script setup>
import { computed, ref, watch } from 'vue';
import { useRoute } from 'vue-router';
import { getCxToken, withCxToken } from 'dashboard/composables/useCxSso';

// CX POC 커스텀 페이지: 우리가 만든 관리자 메뉴(상담워크플로우, 가입 승인, 엑셀 다운로드, 휴무일 달력, 개인정보 정리)를
// 대화창 안이 아니라 왼쪽 사이드바에서 바로 열리는 독립 페이지로 임베드한다.
// 실제 도구는 bot-webhook 컨테이너가 서빙하는 /admin 페이지이며, 매일 바뀌는
// cloudflared 터널 주소는 CX_ADMIN_URL env로 주입되어 boot_start.sh가 자동 갱신한다.
const route = useRoute();
const cxToken = ref('');
const tokenError = ref(false);
// 로그인 연동 토큰(서버가 서명). 받기 전에는 iframe을 만들지 않는다 - 비밀번호 창이 뜨지 않게.
watch(
  () => route.params.accountId,
  async accountId => {
    try {
      cxToken.value = await getCxToken(accountId);
      tokenError.value = false;
    } catch (e) {
      tokenError.value = true;
    }
  },
  { immediate: true }
);
const cxAdminUrl = computed(() => {
  const base = window.chatwootConfig?.cxAdminUrl || '';
  // 사이드바 하위 메뉴가 ?tab=menu|signup|export|holiday|privacy 로
  // 넘겨주면 admin.html이 해당 탭을 바로 열게 그대로 전달한다.
  if (!base || !cxToken.value) return '';
  const url = route.query.tab
    ? `${base}${base.includes('?') ? '&' : '?'}tab=${route.query.tab}`
    : base;
  return withCxToken(url, cxToken.value);
});
</script>

<template>
  <section class="flex flex-col w-full h-full overflow-hidden bg-n-surface-1">
    <div
      v-if="!cxAdminUrl"
      class="flex items-center justify-center w-full h-full"
    >
      <span class="text-base text-n-slate-11">
        {{
          tokenError
            ? '로그인 정보를 확인하지 못했어요. 새로고침 후 다시 시도해주세요.'
            : 'CX_ADMIN_URL이 설정되지 않았거나 불러오는 중이에요.'
        }}
      </span>
    </div>
    <iframe
      v-else
      :src="cxAdminUrl"
      class="w-full h-full border-0"
      title="관리자 메뉴"
    />
  </section>
</template>
