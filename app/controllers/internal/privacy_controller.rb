# CX POC 커스텀 컨트롤러.
# 관리 화면 "개인정보 정리" 탭용 내부 API (도커 내부망에서 bot-webhook만 호출, X-Internal-Token 인증).
# 실제 처리 로직은 CxPrivacyService. 여기서는 대상 고르기/안전장치만 한다.
#
# 안전장치:
# - 종료(resolved)된 대화만 대상 (진행 중인 상담은 절대 건드리지 않음)
# - 한 번에 MAX_BATCH건까지
# - 삭제는 confirm 값이 정확히 '삭제'여야 실행
class Internal::PrivacyController < Internal::BaseController
  MAX_BATCH = 200

  before_action :load_account

  # GET /internal/privacy/conversations?account_id=&days=&filter=unmasked|masked|all
  def index
    scope = filtered_scope
    total = scope.count
    conversations = scope.includes(:contact).order(:last_activity_at).limit(MAX_BATCH).to_a
    ids = conversations.map(&:id)
    # Message에는 created_at 기본 정렬이 걸려 있어서 GROUP BY와 충돌한다 -> reorder(nil)로 정렬을 뺀다
    message_counts = Message.where(conversation_id: ids).reorder(nil).group(:conversation_id).count
    attachment_counts = Attachment.joins(:message).where(messages: { conversation_id: ids }).reorder(nil).group('messages.conversation_id').count

    render json: { success: true, total: total, limit: MAX_BATCH, items: conversations.map { |c| row_for(c, message_counts, attachment_counts) } }
  end

  # POST /internal/privacy/mask  { account_id, display_ids: [..], purge_attachments: bool }
  def mask
    conversations, not_resolved, not_found = pick_conversations
    purge = ActiveModel::Type::Boolean.new.cast(params[:purge_attachments]) || false
    summary = { masked: 0, already_masked: 0, contact_masked: 0, contact_skipped_open: 0, messages_changed: 0, attachments_removed: 0 }

    conversations.each do |conversation|
      if CxPrivacyService.masked?(conversation) && conversation.contact&.custom_attributes&.key?(CxPrivacyService::MASKED_AT_KEY)
        summary[:already_masked] += 1
        next
      end
      result = CxPrivacyService.mask_conversation!(conversation, purge_attachments: purge)
      summary[:masked] += 1
      summary[:contact_masked] += 1 if result[:contact] == :masked
      summary[:contact_skipped_open] += 1 if result[:contact] == :skipped_open_conversation
      summary[:messages_changed] += result[:messages]
      summary[:attachments_removed] += result[:attachments]
    end

    Rails.logger.info("[privacy] mask account=#{@account.id} display_ids=#{conversations.map(&:display_id)} summary=#{summary}")
    render json: { success: true, summary: summary, not_resolved: not_resolved, not_found: not_found }
  end

  # POST /internal/privacy/delete  { account_id, display_ids: [..], confirm: '삭제' }
  def destroy_conversations
    unless params[:confirm].to_s == '삭제'
      return render json: { success: false, error: 'confirm_required' }, status: :unprocessable_entity
    end

    conversations, not_resolved, not_found = pick_conversations
    deleted = 0
    contacts_deleted = 0
    conversations.each do |conversation|
      result = CxPrivacyService.destroy_conversation!(conversation)
      deleted += 1 if result[:deleted]
      contacts_deleted += 1 if result[:contact_deleted]
    end

    Rails.logger.info("[privacy] delete account=#{@account.id} display_ids=#{conversations.map(&:display_id)} deleted=#{deleted} contacts_deleted=#{contacts_deleted}")
    render json: { success: true, summary: { deleted: deleted, contacts_deleted: contacts_deleted },
                   not_resolved: not_resolved, not_found: not_found }
  end

  private

  def load_account
    @account = Account.find_by(id: params[:account_id])
    render json: { success: false, error: 'account_not_found' }, status: :not_found unless @account
  end

  def filtered_scope
    scope = @account.conversations.resolved
    days = params[:days].to_i
    scope = scope.where(conversations: { last_activity_at: ..days.days.ago }) if days.positive?
    masked_sql = "conversations.custom_attributes->>'#{CxPrivacyService::MASKED_AT_KEY}'"
    case params[:filter].to_s
    when 'masked' then scope.where("#{masked_sql} IS NOT NULL")
    when 'all' then scope
    else scope.where("#{masked_sql} IS NULL")
    end
  end

  # 반환: [처리 대상(resolved) 대화들, resolved가 아니라 건너뛴 display_id들, 못 찾은 display_id들]
  def pick_conversations
    display_ids = Array(params[:display_ids]).map(&:to_s).select { |v| v.match?(/\A\d+\z/) }.map(&:to_i).uniq.first(MAX_BATCH)
    found = @account.conversations.where(display_id: display_ids).to_a
    resolved, others = found.partition(&:resolved?)
    [resolved, others.map(&:display_id), display_ids - found.map(&:display_id)]
  end

  def row_for(conversation, message_counts, attachment_counts)
    contact = conversation.contact
    phone = contact&.phone_number.presence || conversation.custom_attributes&.dig('cx_phone')
    {
      display_id: conversation.display_id,
      last_activity_at: conversation.last_activity_at&.iso8601,
      contact_name: CxPrivacyService.mask_name(contact&.name),
      contact_phone: CxPrivacyService.mask_phone(phone),
      messages: message_counts[conversation.id] || 0,
      attachments: attachment_counts[conversation.id] || 0,
      masked: CxPrivacyService.masked?(conversation)
    }
  end
end
