import { frontendURL } from '../../../helper/URLHelper';
import CxAdminIndex from './pages/CxAdminIndex.vue';

// CX POC 커스텀 라우트: 관리자 메뉴(문의 메뉴 빌더, 가입 승인, 엑셀 다운로드, 휴무일, 개인정보 정리)를
// 왼쪽 사이드바에서 바로 여는 독립 페이지. 가입 승인이 민감한 기능이라 관리자만 접근 가능.
export const routes = [
  {
    path: frontendURL('accounts/:accountId/cx-admin'),
    name: 'cx_admin_index',
    component: CxAdminIndex,
    meta: {
      permissions: ['administrator'],
    },
  },
];
