if @conversation
  json.id @conversation.display_id
  json.inbox_id @conversation.inbox_id
  json.contact_last_seen_at @conversation.contact_last_seen_at.to_i
  json.status @conversation.status
  # CX POC 커스텀: 위젯이 custom_attributes(bot_active 등)를 읽을 수 있도록 노출.
  # 원래 이 jbuilder는 custom_attributes를 안 내려줘서, 봇 워크플로우 중엔 입력창을
  # 숨기고 상담원 연결 후에만 보여주는 기능을 위젯 쪽에서 구현할 수가 없었음.
  json.custom_attributes @conversation.custom_attributes
end
