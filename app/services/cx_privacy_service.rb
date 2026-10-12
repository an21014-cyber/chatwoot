# CX POC 커스텀: 종료된 대화의 개인정보 마스킹 / 삭제.
# 관리 화면의 "개인정보 정리" 탭이 bot-webhook을 거쳐 Internal::PrivacyController로 호출한다.
#
# 마스킹: 이름·연락처·이메일을 가린다 (대화 내용은 남김, 통계/분쟁 대응용). 되돌릴 수 없다.
# 삭제:   대화(메시지/첨부 포함)를 영구 삭제하고, 그 고객에게 남은 대화가 없으면 고객 기록도 삭제한다.
#
# 메시지/대화 수정에는 update_columns를 쓴다 - update!는 message_updated 같은 이벤트를 발생시키는데,
# 봇(webhook_bot.py)이 message_updated + submitted_values를 "버튼 클릭"으로 해석하므로
# 지난 대화를 마스킹하다가 봇이 다시 반응하는 사고를 막기 위해서다.
class CxPrivacyService
  MASKED_AT_KEY = 'cx_pii_masked_at'.freeze
  # 대화 custom_attributes 중 가리면 안 되는 값 (업무 식별용 / 시스템 값)
  KEEP_CONVERSATION_KEYS = %w[cx_order_number bot_active].freeze

  # webhook_bot.py의 PHONE_LIKE_RE / MOBILE_NOSEP_RE와 같은 규칙 (두 곳이 같이 바뀌어야 함)
  PHONE_LIKE_RE = /(?<!\d)(\d{2,3})[-\s](\d{3,4})[-\s](\d{4})(?!\d)/
  MOBILE_NOSEP_RE = /(?<!\d)(01[016789])(\d{3,4})(\d{4})(?!\d)/
  EMAIL_RE = /[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/

  class << self
    # ---- 값 하나를 가리는 함수들 (여러 번 적용해도 결과가 같다) ----

    def mask_phone(raw)
      return '' if raw.blank?

      digits = raw.to_s.gsub(/\D/, '')
      digits = "0#{digits[2..]}" if digits.start_with?('82') && [11, 12, 13].include?(digits.length)
      return '*' * digits.length if digits.length < 7

      "#{digits[0, 3]}-****-#{digits[-4, 4]}"
    end

    def mask_name(name)
      return '' if name.blank?

      name.to_s.split(/\s+/).map { |token| "#{token[0]}#{'*' * (token.length - 1)}" }.join(' ')
    end

    def mask_email(email)
      local, domain = email.to_s.split('@', 2)
      return '' if local.blank?

      "#{local[0]}***@#{domain}"
    end

    # 문장 속 전화번호/이메일, 그리고 이미 알고 있는 고객 이름(names)을 가린다.
    def mask_text(text, names = [])
      return text if text.blank?

      out = text.to_s.dup
      names.compact.map(&:to_s).reject { |n| n.length < 2 }.uniq.sort_by { |n| -n.length }.each do |name|
        out = out.gsub(name, mask_name(name))
      end
      out = out.gsub(EMAIL_RE) { |m| mask_email(m) }
      out = out.gsub(PHONE_LIKE_RE) do |m|
        total = Regexp.last_match(1).length + Regexp.last_match(2).length + Regexp.last_match(3).length
        total.between?(9, 11) ? "#{Regexp.last_match(1)}-****-#{Regexp.last_match(3)}" : m
      end
      out.gsub(MOBILE_NOSEP_RE) { "#{Regexp.last_match(1)}-****-#{Regexp.last_match(3)}" }
    end

    def mask_json(value, names)
      case value
      when String then mask_text(value, names)
      when Array then value.map { |v| mask_json(v, names) }
      when Hash then value.transform_values { |v| mask_json(v, names) }
      else value
      end
    end

    # ---- 대화 단위 처리 ----

    # 반환: { masked: true/false, contact: :masked|:skipped_open_conversation|:already|:none,
    #         messages: 바뀐 메시지 수, attachments: 지운 첨부 수 }
    def mask_conversation!(conversation, purge_attachments: false)
      contact = conversation.contact
      names = collect_names(conversation, contact)
      result = { masked: true, contact: :none, messages: 0, attachments: 0 }

      ActiveRecord::Base.transaction do
        result[:messages], result[:attachments] = mask_messages(conversation, names, purge_attachments)
        mask_conversation_attributes(conversation, names)
        result[:contact] = mask_contact(contact, names) if contact
      end
      result
    end

    def masked?(conversation)
      conversation.custom_attributes&.key?(MASKED_AT_KEY) || false
    end

    # 대화를 영구 삭제. 그 고객에게 남은 대화가 없으면 고객 기록도 같이 삭제한다.
    # 메시지/첨부 삭제는 Chatwoot 기본 동작(destroy_async)대로 sidekiq이 이어서 처리한다.
    def destroy_conversation!(conversation)
      contact = conversation.contact
      contact_deleted = false
      ActiveRecord::Base.transaction do
        conversation.destroy!
        if contact && !Conversation.exists?(contact_id: contact.id)
          contact.destroy!
          contact_deleted = true
        end
      end
      { deleted: true, contact_deleted: contact_deleted }
    end

    private

    def collect_names(conversation, contact)
      names = []
      if contact
        names << contact.name
        names << contact.last_name
        names << "#{contact.last_name}#{contact.name}"
      end
      names << conversation.custom_attributes&.dig('cx_name')
      names.reject(&:blank?).uniq
    end

    def mask_messages(conversation, names, purge_attachments)
      changed = 0
      removed = 0
      conversation.messages.find_each do |message|
        attrs = {}
        content = mask_text(message.content, names)
        attrs[:content] = content if content != message.content
        processed = mask_text(message.processed_message_content, names)
        attrs[:processed_message_content] = processed if processed != message.processed_message_content
        content_attributes = mask_json(message.content_attributes, names)
        attrs[:content_attributes] = content_attributes if content_attributes != message.content_attributes
        additional = mask_json(message.additional_attributes, names)
        attrs[:additional_attributes] = additional if additional != message.additional_attributes
        if attrs.any?
          message.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
          changed += 1
        end
        next unless purge_attachments

        message.attachments.each do |attachment|
          attachment.destroy!
          removed += 1
        end
      end
      [changed, removed]
    end

    def mask_conversation_attributes(conversation, names)
      attrs = (conversation.custom_attributes || {}).dup
      attrs.each do |key, value|
        next if KEEP_CONVERSATION_KEYS.include?(key) || !value.is_a?(String)

        attrs[key] = mask_text(value, names)
      end
      attrs['cx_phone'] = mask_phone(attrs['cx_phone']) if attrs['cx_phone'].present?
      attrs['cx_name'] = mask_name(attrs['cx_name']) if attrs['cx_name'].present?
      attrs[MASKED_AT_KEY] = Time.current.iso8601
      conversation.update_columns(custom_attributes: attrs) # rubocop:disable Rails/SkipsModelValidations
    end

    # 같은 고객이 아직 진행 중인 대화가 있으면 고객 정보는 건드리지 않는다
    # (상담원이 보고 있는 화면의 이름/연락처가 갑자기 사라지는 걸 막기 위해).
    def mask_contact(contact, names)
      return :already if contact.custom_attributes&.key?(MASKED_AT_KEY)
      return :skipped_open_conversation if contact.conversations.where.not(status: :resolved).exists?

      contact.avatar.purge if contact.avatar.attached?
      contact.notes.find_each do |note|
        note.update_columns(content: mask_text(note.content, names)) # rubocop:disable Rails/SkipsModelValidations
      end
      contact.update_columns( # rubocop:disable Rails/SkipsModelValidations
        name: mask_name(contact.name), middle_name: '', last_name: '', email: nil, phone_number: nil,
        identifier: nil, location: '', country_code: '', additional_attributes: {},
        custom_attributes: { MASKED_AT_KEY => Time.current.iso8601 }
      )
      :masked
    end
  end
end
