<script>
import { mapGetters, mapActions } from 'vuex';

import ChatFooter from '../components/ChatFooter.vue';
import ConversationWrap from '../components/ConversationWrap.vue';
import { SILENT_WORKFLOW_TRIGGER } from 'widget/helpers/constants';

export default {
  components: { ChatFooter, ConversationWrap },
  computed: {
    ...mapGetters({
      groupedMessages: 'conversation/getGroupedConversation',
      conversationSize: 'conversation/getConversationSize',
    }),
  },
  mounted() {
    this.$store.dispatch('conversation/setUserLastSeen');
    // CX POC 커스텀: 고객이 직접 뭔가 입력해야만 봇 워크플로우(첫 인사+메뉴)가 시작되던 걸,
    // 채팅 화면에 처음 들어오는 순간 자동으로 시작되게 한다 - 화면엔 안 보이는 "보이지 않는"
    // 첫 메시지를 대신 보내서 대화를 만들고, 봇은 이걸 평소 첫 메시지처럼 받아서 반응한다
    // (webhook_bot.py는 그대로, 화면에서만 이 메시지를 숨김 - conversation/getters.js 참고).
    if (!this.conversationSize) {
      this.createConversation({ message: SILENT_WORKFLOW_TRIGGER });
    }
  },
  methods: {
    ...mapActions('conversation', ['createConversation']),
  },
};
</script>

<template>
  <div
    class="flex flex-col flex-1 overflow-hidden rounded-b-lg bg-n-slate-2 dark:bg-n-solid-1"
  >
    <div class="flex flex-1 overflow-auto">
      <ConversationWrap :grouped-messages="groupedMessages" />
    </div>
    <ChatFooter class="px-5" />
  </div>
</template>
