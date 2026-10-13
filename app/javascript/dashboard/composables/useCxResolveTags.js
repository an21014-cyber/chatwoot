// CX POC 커스텀: 상담 종료 때 태그 입력 창(CxResolveTagsModal)을 여는 공용 상태.
// 종료 버튼/단축키/목록의 오른쪽 클릭 메뉴가 모두 requestResolveWithTags()를 거치고, 태그를 저장한 뒤 onDone()이 실제 종료를 한다.
// 열 때 대화를 붙잡아 두므로(단축키로 다음 대화로 넘어가도) 종료와 태그는 항상 같은 대화에 적용된다.
import { reactive } from 'vue';

export const cxResolveTagsState = reactive({
  open: false,
  conversation: null,
  onDone: null,
});

export function requestResolveWithTags(conversation, onDone) {
  if (!conversation) return;
  cxResolveTagsState.conversation = conversation;
  cxResolveTagsState.onDone = onDone;
  cxResolveTagsState.open = true;
}
