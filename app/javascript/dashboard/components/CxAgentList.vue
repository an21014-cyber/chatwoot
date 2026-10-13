<script setup>
import { computed, provide, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useAccount } from 'dashboard/composables/useAccount';
import { useMapGetter } from 'dashboard/composables/store';
import { useCxAssigneeCounts } from 'dashboard/composables/useCxAssigneeCounts';
import ConversationApi from 'dashboard/api/inbox/conversation';
import ConversationList from './ConversationList.vue';
import Avatar from 'next/avatar/Avatar.vue';

// CX POC 커스텀(채널톡식 담당자 화면): 사이드바 "담당자"에서 사람을 누르면 그 사람의 대화를 상태별로 보여준다.
//  - 상담원: 진행중(open) / 보류중(snoozed) / 종료됨(resolved - 종료된 대화도 담당자가 그대로 남아 "내가 종료한 상담"이 된다)
//  - 담당자 없음: 진행중 / 대기(봇 응대 중) / 종료됨
// 목록은 서버에서 25건씩 불러와 기존 대화 저장소(store)에 합치고, 화면에는 저장소에서 조건에 맞는 것만 골라 보여준다
// (실시간으로 들어오는 대화 변경도 그대로 반영된다). 대화를 누르면 오른쪽에 기존 대화창이 열린다.
const props = defineProps({
  agentId: { type: [String, Number], required: true },
  showConversationList: { type: Boolean, default: true },
  isOnExpandedLayout: { type: Boolean, default: false },
});

const PER_PAGE = 25;
const store = useStore();
const { accountId } = useAccount();
const agents = useMapGetter('agents/getAgents');
const allConversations = useMapGetter('getAllConversations');
const currentUserId = useMapGetter('getCurrentUserID');
const { counts, refresh } = useCxAssigneeCounts(accountId);

const status = ref(String(props.agentId) === 'bot' ? 'pending' : 'open');
const loading = ref(false);
const page = ref(1);
const hasMore = ref(true);

const isUnassigned = computed(() => String(props.agentId) === 'unassigned');
const isBot = computed(() => String(props.agentId) === 'bot');
const agent = computed(() =>
  isUnassigned.value || isBot.value
    ? null
    : (agents.value || []).find(a => String(a.id) === String(props.agentId))
);
const isMe = computed(() => String(props.agentId) === String(currentUserId.value));
const title = computed(() => {
  if (isUnassigned.value) return '담당자 없음';
  if (isBot.value) return 'CX 문의봇';
  return `${agent.value?.name || '담당자'}${isMe.value ? ' (나)' : ''}`;
});

const TAB_LABELS = computed(() => ({
  open: '진행중',
  snoozed: '보류중',
  pending: isBot.value ? '응대 중' : '대기',
  resolved: '종료됨',
}));
const tabKeys = computed(() => {
  if (isBot.value) return ['pending', 'open', 'resolved'];
  if (isUnassigned.value) return ['open', 'pending', 'resolved'];
  return ['open', 'snoozed', 'resolved'];
});
const agentCounts = computed(
  () =>
    counts.value[
      isUnassigned.value ? 'unassigned' : String(props.agentId)
    ] || {}
);

const list = computed(() =>
  (allConversations.value || [])
    .filter(chat => {
      if (chat.status !== status.value) return false;
      if (isBot.value) return chat.meta?.assignee_type === 'AgentBot';
      const assigneeId = chat.meta?.assignee?.id;
      return isUnassigned.value
        ? !assigneeId
        : chat.meta?.assignee_type !== 'AgentBot' &&
            assigneeId === Number(props.agentId);
    })
    .sort((a, b) => (b.last_activity_at || 0) - (a.last_activity_at || 0))
);

async function load(reset) {
  if (reset) {
    page.value = 1;
    hasMore.value = true;
  }
  if (loading.value && !reset) return;
  if (!hasMore.value) return;
  const requestKey = `${props.agentId}:${status.value}`;
  loading.value = true;
  try {
    const {
      data: { data },
    } = await ConversationApi.get({
      status: status.value,
      assigneeType: (() => {
        if (isUnassigned.value) return 'unassigned';
        return isBot.value ? 'bot' : 'all';
      })(),
      assigneeId: isUnassigned.value || isBot.value ? undefined : props.agentId,
      page: page.value,
    });
    store.commit('SET_ALL_CONVERSATION', data.payload);
    // 그 사이 다른 담당자/탭으로 바뀌었으면 페이지 상태는 건드리지 않는다
    if (requestKey === `${props.agentId}:${status.value}`) {
      hasMore.value = data.payload.length >= PER_PAGE;
      page.value += 1;
    }
  } catch (e) {
    hasMore.value = false;
  } finally {
    loading.value = false;
  }
}

watch(
  () => [props.agentId, status.value],
  () => {
    // 다른 종류의 보기(사람/봇/담당자 없음)로 옮겼는데 그 보기에 없는 탭이면 첫 탭으로
    if (!tabKeys.value.includes(status.value)) {
      status.value = tabKeys.value[0];
      return;
    }
    load(true);
    refresh();
  },
  { immediate: true }
);

// ConversationItem이 목록 부모(ChatList)에서 받아 쓰던 동작들. 이 화면에서는 일괄 선택이 없고, 오른쪽 클릭 메뉴는
// 상태/우선순위/읽음만 연결한다 (담당자·라벨 변경은 대화창 위쪽에서 한다).
provide('selectConversation', () => {});
provide('deSelectConversation', () => {});
provide('isConversationSelected', () => false);
provide('assignAgent', () => {});
provide('assignTeam', () => {});
provide('assignLabels', () => {});
provide('removeLabels', () => {});
provide('deleteConversation', () => {});
provide('updateConversationStatus', (conversationId, newStatus, snoozedUntil) => {
  store.dispatch('toggleStatus', { conversationId, status: newStatus, snoozedUntil });
});
provide('assignPriority', (priority, conversationId = null) => {
  store.dispatch('setCurrentChatPriority', { priority, conversationId });
  store.dispatch('assignPriority', { conversationId, priority });
});
provide('markAsUnread', id => store.dispatch('markMessagesUnread', { id }));
provide('markAsRead', id => store.dispatch('markMessagesRead', { id }));
</script>

<template>
  <div
    class="flex flex-col flex-shrink-0 conversations-list-wrap bg-n-surface-1 relative"
    :class="[
      { hidden: !showConversationList },
      isOnExpandedLayout ? 'basis-full' : 'w-[340px] 2xl:w-[412px]',
    ]"
  >
    <div class="flex items-center gap-2 px-3 h-[3.25rem]">
      <Avatar
        v-if="agent"
        :name="agent.name"
        :src="agent.thumbnail"
        :size="28"
        :status="agent.availability_status"
        hide-offline-status
      />
      <span
        v-else
        class="grid place-content-center size-7 rounded-full bg-n-slate-4 text-n-slate-11"
      >
        <span :class="isBot ? 'i-lucide-bot' : 'i-lucide-user-x'" class="size-4" />
      </span>
      <h1 class="text-base font-bold truncate text-n-slate-12" :title="title">
        {{ title }}
      </h1>
    </div>

    <div class="flex gap-1 px-3 pb-2">
      <button
        v-for="key in tabKeys"
        :key="key"
        type="button"
        class="flex items-center gap-1.5 px-3 py-1.5 text-sm rounded-full transition-colors"
        :class="
          status === key
            ? 'bg-n-blue-3 text-n-blue-11 font-semibold'
            : 'text-n-slate-11 hover:bg-n-alpha-2'
        "
        @click="status = key"
      >
        {{ TAB_LABELS[key] }}
        <span
          class="px-1.5 text-xs rounded-full"
          :class="
            status === key ? 'bg-n-blue-4 text-n-blue-11' : 'bg-n-alpha-1 text-n-slate-10'
          "
        >
          {{ agentCounts[key] || 0 }}
        </span>
      </button>
    </div>

    <p
      v-if="!loading && !list.length"
      class="flex justify-center items-center p-6 text-n-slate-11"
    >
      비어 있는 상담목록입니다.
    </p>
    <ConversationList
      :conversation-list="list"
      :is-loading="loading"
      :show-end-of-list-message="!hasMore && list.length > 0"
      :agent-id="agentId"
      :show-assignee="isUnassigned || isBot"
      :is-on-expanded-layout="isOnExpandedLayout"
      @load-more="load(false)"
    />
  </div>
</template>
