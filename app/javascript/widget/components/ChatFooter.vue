<script>
import { mapActions, mapGetters } from 'vuex';
import { getContrastingTextColor } from '@chatwoot/utils';
import CustomButton from 'shared/components/Button.vue';
import FooterReplyTo from 'widget/components/FooterReplyTo.vue';
import ChatInputWrap from 'widget/components/ChatInputWrap.vue';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { sendEmailTranscript } from 'widget/api/conversation';
import { emitter } from 'shared/helpers/mitt';
import { SILENT_WORKFLOW_TRIGGER } from 'widget/helpers/constants';

const TRANSCRIPT_COOLDOWN_MS = 15000;

export default {
  components: {
    ChatInputWrap,
    CustomButton,
    FooterReplyTo,
  },
  data() {
    return {
      inReplyTo: null,
      isSendingTranscript: false,
      transcriptCooldown: false,
      transcriptCooldownTimer: null,
    };
  },
  computed: {
    ...mapGetters({
      conversationAttributes: 'conversationAttributes/getConversationParams',
      widgetColor: 'appConfig/getWidgetColor',
      conversationSize: 'conversation/getConversationSize',
      currentUser: 'contacts/getCurrentUser',
      isWidgetStyleFlat: 'appConfig/isWidgetStyleFlat',
    }),
    textColor() {
      return getContrastingTextColor(this.widgetColor);
    },
    isResolved() {
      return this.conversationAttributes.status === 'resolved';
    },
    hideReplyBox() {
      // CX POC 커스텀: 상담원에게 연결되기 전(봇이 버튼 메뉴로 응대 중)에는 자유 텍스트
      // 입력을 막는다 - 봇이 첫 인사를 보낼 때 conversation custom_attributes.bot_active를
      // true로 켜고, "상담원 연결" 노드가 실행되면 false로 꺼준다 (webhook_bot.py 참고).
      // 종료된(resolved) 대화는 이 값과 상관없이 항상 footer 자체는 보여주되(아래
      // "새로운 대화 시작하기" 버튼을 위해), 자유 텍스트 입력창은 계속 숨긴다 - 처음부터
      // 다시 진행해야 하는 게 맞다는 요청(2026-09-16)에 따라 입력창 대신 버튼만 노출.
      if (this.isResolved) return false;
      return this.conversationAttributes?.custom_attributes?.bot_active === true;
    },
    showEmailTranscriptButton() {
      return this.hasEmail;
    },
    hasEmail() {
      return this.currentUser && this.currentUser.has_email;
    },
    hasReplyTo() {
      return (
        this.inReplyTo && (this.inReplyTo.content || this.inReplyTo.attachments)
      );
    },
  },
  mounted() {
    emitter.on(BUS_EVENTS.TOGGLE_REPLY_TO_MESSAGE, this.toggleReplyTo);
  },
  beforeUnmount() {
    clearTimeout(this.transcriptCooldownTimer);
  },
  methods: {
    ...mapActions('conversation', [
      'sendMessage',
      'sendAttachment',
      'createConversation',
      'clearConversations',
    ]),
    ...mapActions('conversationAttributes', [
      'getAttributes',
      'clearConversationAttributes',
    ]),
    async handleSendMessage(content) {
      await this.sendMessage({
        content,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      // reset replyTo message after sending
      this.inReplyTo = null;
      // Update conversation attributes on new conversation
      if (this.conversationSize === 0) {
        this.getAttributes();
      }
    },
    // CX POC 커스텀: 종료된 대화의 입력창 자리에 뜨는 "새로운 대화 시작하기" 버튼 핸들러.
    // 첫 방문 때 자동으로 워크플로우를 시작시키는 것과 똑같은 방식(SILENT_WORKFLOW_TRIGGER)으로
    // 새 대화를 만들어서, 고객이 뭘 치지 않아도 바로 봇 인사말부터 다시 시작되게 한다.
    async startNewConversation() {
      this.clearConversations();
      this.clearConversationAttributes();
      await this.createConversation({ message: SILENT_WORKFLOW_TRIGGER });
    },
    async handleSendAttachment(attachment) {
      await this.sendAttachment({
        attachment,
        replyTo: this.inReplyTo ? this.inReplyTo.id : null,
      });
      this.inReplyTo = null;
    },
    toggleReplyTo(message) {
      this.inReplyTo = message;
    },
    startTranscriptCooldown() {
      this.transcriptCooldown = true;
      clearTimeout(this.transcriptCooldownTimer);
      this.transcriptCooldownTimer = setTimeout(() => {
        this.transcriptCooldown = false;
      }, TRANSCRIPT_COOLDOWN_MS);
    },
    async sendTranscript() {
      if (
        !this.hasEmail ||
        this.isSendingTranscript ||
        this.transcriptCooldown
      ) {
        return;
      }
      this.isSendingTranscript = true;
      try {
        await sendEmailTranscript();
        this.startTranscriptCooldown();
        emitter.emit(BUS_EVENTS.SHOW_ALERT, {
          message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_SUCCESS'),
          type: 'success',
        });
      } catch (error) {
        emitter.emit(BUS_EVENTS.SHOW_ALERT, {
          message: this.$t('EMAIL_TRANSCRIPT.SEND_EMAIL_ERROR'),
        });
      } finally {
        this.isSendingTranscript = false;
      }
    },
  },
};
</script>

<template>
  <footer
    v-if="!hideReplyBox"
    class="relative z-50 mb-1"
    :class="{
      'rounded-lg': !isWidgetStyleFlat,
      'pt-2.5 shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.05)] dark:shadow-[0px_-20px_20px_1px_rgba(0,_0,_0,_0.15)] rounded-t-none':
        hasReplyTo,
    }"
  >
    <FooterReplyTo
      v-if="hasReplyTo"
      :in-reply-to="inReplyTo"
      @dismiss="inReplyTo = null"
    />
    <CustomButton
      v-if="isResolved && showEmailTranscriptButton"
      type="clear"
      class="font-normal"
      :disabled="isSendingTranscript || transcriptCooldown"
      @click="sendTranscript"
    >
      {{ $t('EMAIL_TRANSCRIPT.BUTTON_TEXT') }}
    </CustomButton>
    <!-- CX POC 커스텀: 종료된 대화는 자유 텍스트 입력창 대신 이 버튼만 보여준다 - 눌러야만
         새 대화가 만들어지고 처음부터(봇 인사말부터) 다시 진행된다. -->
    <CustomButton
      v-if="isResolved"
      lg
      class="w-full"
      @click="startNewConversation"
    >
      {{ $t('START_NEW_CONVERSATION') }}
    </CustomButton>
    <ChatInputWrap
      v-else
      class="shadow-sm"
      :on-send-message="handleSendMessage"
      :on-send-attachment="handleSendAttachment"
    />
  </footer>
</template>
