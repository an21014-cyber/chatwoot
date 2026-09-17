export const APP_BASE_URL = '';

export const MESSAGE_STATUS = {
  FAILED: 'failed',
  SUCCESS: 'success',
  PROGRESS: 'progress',
};

export const MESSAGE_TYPE = {
  INCOMING: 0,
  OUTGOING: 1,
  ACTIVITY: 2,
  TEMPLATE: 3,
};

export const WOOT_PREFIX = 'chatwoot-widget:';

// CX POC 커스텀: 고객이 아무것도 입력하지 않아도 봇 워크플로우가 바로 시작되도록,
// 첫 진입 시 이 내용으로 "보이지 않는" 첫 메시지를 자동 전송해서 대화를 만든다
// (Messages.vue 참고). 고객이 실제로 이 문구를 친 게 아니라는 걸 구분하고, 화면에는
// 절대 보이면 안 되므로 getGroupedConversation에서 이 값과 content가 일치하는
// 메시지는 항상 걸러낸다.
export const SILENT_WORKFLOW_TRIGGER = '__cx_workflow_autostart__';
