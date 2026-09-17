import { MESSAGE_TYPE, SILENT_WORKFLOW_TRIGGER } from 'widget/helpers/constants';
import { groupBy } from 'widget/helpers/utils';
import { groupConversationBySender } from './helpers';
import { formatUnixDate } from 'shared/helpers/DateHelper';

export const getters = {
  getAllMessagesLoaded: _state => _state.uiFlags.allMessagesLoaded,
  getIsCreating: _state => _state.uiFlags.isCreating,
  getIsAgentTyping: _state => _state.uiFlags.isAgentTyping,
  getConversation: _state => _state.conversations,
  getConversationSize: _state => Object.keys(_state.conversations).length,
  getEarliestMessage: _state => {
    const conversation = Object.values(_state.conversations);
    if (conversation.length) {
      return conversation[0];
    }
    return {};
  },
  getLastMessage: _state => {
    const conversation = Object.values(_state.conversations);
    if (conversation.length) {
      return conversation[conversation.length - 1];
    }
    return {};
  },
  getGroupedConversation: _state => {
    // CX POC 커스텀: 워크플로우를 자동으로 시작시키려고 보낸 "보이지 않는" 첫 메시지는
    // 실제 대화 내용이 아니므로 화면에 절대 나오면 안 된다 (Messages.vue 참고).
    const visibleMessages = Object.values(_state.conversations).filter(
      message => message.content !== SILENT_WORKFLOW_TRIGGER
    );
    const conversationGroupedByDate = groupBy(visibleMessages, message =>
      formatUnixDate(message.created_at)
    );
    return Object.keys(conversationGroupedByDate).map(date => ({
      date,
      messages: groupConversationBySender(conversationGroupedByDate[date]),
    }));
  },
  getPendingCustomAttributes: _state => _state.pendingCustomAttributes,
  getPendingLabels: _state => _state.pendingLabels,
  getIsFetchingList: _state => _state.uiFlags.isFetchingList,
  getMessageCount: _state => {
    return Object.values(_state.conversations).length;
  },
  getUnreadMessageCount: _state => {
    const { userLastSeenAt } = _state.meta;
    return Object.values(_state.conversations).filter(chat => {
      const { created_at: createdAt, message_type: messageType } = chat;
      const isOutGoing = messageType === MESSAGE_TYPE.OUTGOING;
      const hasNotSeen = userLastSeenAt
        ? createdAt * 1000 > userLastSeenAt * 1000
        : true;
      return hasNotSeen && isOutGoing;
    }).length;
  },
  getUnreadTextMessages: (_state, _getters) => {
    const unreadCount = _getters.getUnreadMessageCount;
    const allMessages = [...Object.values(_state.conversations)];
    const unreadAgentMessages = allMessages.filter(message => {
      const { message_type: messageType } = message;
      return messageType === MESSAGE_TYPE.OUTGOING;
    });
    const maxUnreadCount = Math.min(unreadCount, 3);
    return unreadAgentMessages.splice(-maxUnreadCount);
  },
};
