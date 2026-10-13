<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute } from 'vue-router';
import { getCxToken, withCxToken } from 'dashboard/composables/useCxSso';

// CX POC 커스텀: 대화를 열면 오른쪽 고객 정보 위에 "예약 정보" 카드를 보여준다.
// 실제 화면은 bot-webhook이 서빙하는 /reservation 페이지(예약 단건 조회 API 연동)이고, 대화에 이미 있는
// 예약번호/이름/연락처(고객이 폼에 입력한 값)로 자동 조회한다. 봇 주소는 관리자 메뉴와 같은 CX_ADMIN_URL에서
// "/admin"만 떼서 쓴다 (터널 주소가 바뀌어도 boot_start.sh가 CX_ADMIN_URL만 갱신하면 같이 따라간다).
const props = defineProps({
  conversationId: { type: [Number, String], required: true },
});

const open = ref(true);
const route = useRoute();
const cxToken = ref('');
const frameRef = ref(null);
const frameHeight = ref(420);

const baseUrl = computed(() =>
  (window.chatwootConfig?.cxAdminUrl || '').replace(/\/admin(\?.*)?$/, '')
);
const src = computed(() => {
  if (!baseUrl.value || !cxToken.value) return '';
  const theme = document.documentElement.classList.contains('dark')
    ? 'dark'
    : 'light';
  return withCxToken(
    `${baseUrl.value}/reservation?conversation_id=${props.conversationId}&theme=${theme}`,
    cxToken.value
  );
});

// 카드 안 페이지가 자기 내용 높이를 알려주면 iframe 높이를 거기에 맞춘다 (우리 iframe이 보낸 메시지만 받음)
const onMessage = event => {
  if (!frameRef.value || event.source !== frameRef.value.contentWindow) return;
  const h = Number(event.data?.cxReservationHeight);
  if (h > 0) frameHeight.value = Math.min(Math.max(h + 4, 120), 1400);
};
onMounted(async () => {
  window.addEventListener('message', onMessage);
  try {
    cxToken.value = await getCxToken(route.params.accountId);
  } catch (e) {
    cxToken.value = ''; // 토큰을 못 받으면 카드를 숨긴다 (비밀번호 창이 뜨는 것보다 낫다)
  }
});
onBeforeUnmount(() => window.removeEventListener('message', onMessage));
</script>

<template>
  <div v-if="src" class="px-2 pb-3">
    <div
      class="rounded-2xl outline outline-1 outline-n-weak bg-n-solid-2 overflow-hidden"
    >
      <button
        type="button"
        class="flex items-center justify-between w-full px-4 py-2.5 text-sm font-semibold text-n-slate-12"
        @click="open = !open"
      >
        <span class="flex items-center gap-2">
          <span
            class="grid place-content-center size-7 rounded-lg bg-[#E6EEFE] text-[#2F6FED] dark:bg-[#1B2C52] dark:text-[#9DBBF8]"
          >
            <span class="i-lucide-calendar-check size-4" />
          </span>
          예약 정보
        </span>
        <span
          class="size-4 text-n-slate-10"
          :class="open ? 'i-lucide-chevron-up' : 'i-lucide-chevron-down'"
        />
      </button>
      <iframe
        v-if="open"
        ref="frameRef"
        :key="conversationId"
        :src="src"
        class="block w-full border-0"
        :style="{ height: `${frameHeight}px` }"
        title="예약 정보"
      />
    </div>
  </div>
</template>
