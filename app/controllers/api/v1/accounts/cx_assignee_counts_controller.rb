# CX POC 커스텀: 사이드바 "담당자" 목록의 건수(진행중/대기/보류/종료)를 담당자별로 한 번에 집계한다.
# 대화 목록 API와 같은 권한 필터(Conversations::PermissionFilterService)를 거쳐서, 보는 사람이 접근할 수 없는 대화는 세지 않는다.
class Api::V1::Accounts::CxAssigneeCountsController < Api::V1::Accounts::BaseController
  STATUS_KEYS = %w[open pending snoozed resolved].freeze

  def show
    scope = Conversations::PermissionFilterService.new(Current.account.conversations, Current.user, Current.account).perform
    counts = Hash.new { |hash, key| hash[key] = STATUS_KEYS.index_with { 0 } }
    scope.group(:assignee_id, :assignee_agent_bot_id, :status).count.each do |(assignee_id, bot_id, status), count|
      status_key = status.is_a?(Integer) ? Conversation.statuses.key(status) : status.to_s
      next unless STATUS_KEYS.include?(status_key)

      # 사람 담당자 > 봇 > 담당자 없음 (대화 목록 API의 assigned/unassigned 조건과 같은 기준)
      key = assignee_id.nil? ? (bot_id.nil? ? 'unassigned' : 'bot') : assignee_id.to_s
      counts[key][status_key] += count
    end
    render json: { counts: counts }
  end
end
