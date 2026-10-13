// CX POC 커스텀(디자인 A): 사이드바 아이콘 타일 색. 메뉴 이름(name) -> 색 이름.
// 클래스는 Tailwind가 소스에서 찾을 수 있도록 완성된 문자열로 적어야 한다.
const TONES = {
  blue: 'bg-[#E6EEFE] text-[#2F6FED] dark:bg-[#1B2C52] dark:text-[#9DBBF8]',
  violet: 'bg-[#EFE9FE] text-[#6B4FD8] dark:bg-[#2A2350] dark:text-[#C2B3FF]',
  green: 'bg-[#E3F6EC] text-[#17935A] dark:bg-[#12332A] dark:text-[#6FE0A8]',
  amber: 'bg-[#FFF1DB] text-[#C77700] dark:bg-[#3A2A10] dark:text-[#FFC266]',
  rose: 'bg-[#FDE8EC] text-[#D6314F] dark:bg-[#3A1D22] dark:text-[#FF9AAB]',
  teal: 'bg-[#DFF5F5] text-[#0E8A8F] dark:bg-[#10302F] dark:text-[#6FDADD]',
  slate: 'bg-[#EDF0F5] text-[#5B6577] dark:bg-[#262B36] dark:text-[#A9B2C3]',
};

const NAME_TONE = {
  Inbox: 'rose',
  Conversation: 'blue',
  'CX Admin': 'violet',
  Contacts: 'green',
  Reports: 'amber',
  Settings: 'slate',
  // 대화
  All: 'blue',
  Mentions: 'amber',
  Participating: 'green',
  Unattended: 'rose',
  Folders: 'violet',
  Teams: 'teal',
  Channels: 'blue',
  Labels: 'amber',
  // 연락처
  'All Contacts': 'blue',
  Active: 'green',
  Segments: 'violet',
  'Tagged With': 'amber',
  // 보고서
  'Report Overview': 'blue',
  'Report Conversation': 'violet',
  'Reports CSAT': 'amber',
  'Reports Agent': 'green',
  'Reports Label': 'teal',
  'Reports Inbox': 'rose',
  'Reports Team': 'teal',
  // 관리자 메뉴
  'CX Admin Workflow': 'blue',
  'CX Admin Signup': 'green',
  'CX Admin Stats': 'amber',
  'CX Admin Export': 'teal',
  'CX Admin Holiday': 'rose',
  'CX Admin Privacy': 'violet',
  // 설정
  'Settings Account Settings': 'blue',
  'Settings Agents': 'green',
  'Settings Teams': 'teal',
  'Settings Inboxes': 'violet',
  'Settings Labels': 'amber',
  'Settings Custom Attributes': 'rose',
  'Settings Automation': 'violet',
  'Settings Agent Bots': 'blue',
  'Settings Canned Responses': 'green',
  'Settings Integrations': 'amber',
  'Settings Security': 'slate',
};

export const toneClass = name => {
  const key = String(name || '').split(':').pop();
  return TONES[NAME_TONE[key]] || TONES.slate;
};
