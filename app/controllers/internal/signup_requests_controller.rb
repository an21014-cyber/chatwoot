# CX POC 커스텀 컨트롤러.
# 구글 로그인으로 들어온 가입 요청(SignupRequest)을 관리자가 승인/거절하는 내부 API.
class Internal::SignupRequestsController < Internal::BaseController
  # CX POC 커스텀: Chatwoot 기본 role(administrator/agent) 위에 3단계 권한을 둔다.
  # - super_admin -> Chatwoot role administrator, 상담워크플로우 + 가입 승인 관리 모두 접근
  # - admin       -> Chatwoot role administrator, 상담워크플로우만 접근 (가입 승인 관리는 숨김)
  # - operator    -> Chatwoot role agent, 관리자 메뉴 자체가 안 보이고 일반 상담만
  # 화면 노출 여부는 User#custom_attributes['cx_admin_level']를 프론트(Sidebar.vue)에서 읽어 판단한다.
  LEVELS = %w[super_admin admin operator].freeze

  def index
    requests = SignupRequest.order(created_at: :desc).to_a
    json = requests.as_json(only: [:id, :email, :name, :avatar_url, :status, :account_id, :created_at, :reviewed_at,
                                   :display_name, :phone_number, :department, :job_title])
    json.each_with_index do |row, i|
      user = User.from_email(requests[i].email)
      row['level'] = user&.custom_attributes&.dig('cx_admin_level')
      merge_profile_from_user!(row, user) if user
    end
    render json: json
  end

  def approve
    signup_request = SignupRequest.find(params[:id])
    level = valid_level(params[:level])

    apply_level!(signup_request, level)
    signup_request.update!(status: :approved, reviewed_at: Time.current, encrypted_password: nil)

    render json: { success: true, email: signup_request.email, level: level }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'not_found' }, status: :not_found
  end

  # 이미 승인된 계정의 권한 단계만 바꾼다 (승인 상태/가입 요청 자체는 그대로 둠).
  def set_level
    signup_request = SignupRequest.find(params[:id])
    level = valid_level(params[:level])

    apply_level!(signup_request, level)

    render json: { success: true, email: signup_request.email, level: level }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'not_found' }, status: :not_found
  end

  # 가입 신청 화면(공개)에서 들어온 신청을 접수한다. 승인 대기(pending)로만 만들고, 사용자는 승인될 때 만들어진다.
  # 입력한 비밀번호는 평문으로 보관하지 않고 Devise 해시로만 둔다(승인 시 사용자 비밀번호로 그대로 옮김).
  # 공개 입구라서 스팸을 막기 위해 대기 중인 신청이 너무 많으면 더 받지 않는다.
  MAX_PENDING_APPLICATIONS = 50

  def apply
    attrs = application_attributes
    errors = application_errors(attrs)
    return render json: { success: false, errors: errors }, status: :unprocessable_entity if errors.any?

    existing = SignupRequest.find_by(email: attrs[:email])
    return render json: { success: false, errors: ['이미 신청했거나 가입된 이메일이에요.'] }, status: :conflict if existing && !existing.rejected?
    return render json: { success: false, errors: ['신청이 몰려 있어요. 잠시 후 다시 시도해주세요.'] }, status: :too_many_requests if SignupRequest.pending.count >= MAX_PENDING_APPLICATIONS

    signup_request = existing || SignupRequest.new(email: attrs[:email])
    signup_request.assign_attributes(
      attrs.slice(:name, :display_name, :phone_number, :department, :job_title).merge(
        account_id: ENV.fetch('CX_ACCOUNT_ID', '35').to_i, status: :pending, reviewed_at: nil,
        encrypted_password: Devise::Encryptor.digest(User, attrs[:password])
      )
    )
    signup_request.save!
    render json: { success: true }
  end

  # 승인된 계정의 이름/표시 이름/이메일/연락처/부서/직책을 고치고, 원하면 임시 비밀번호를 새로 만들어 준다(한 번만 응답에 담아 돌려줌).
  # - 이메일은 로그인 아이디이자 가입 요청의 키라서 User와 SignupRequest를 함께 바꾼다(다른 계정과 겹치면 거절).
  # - 비밀번호를 재설정하면 이미 로그인된 기기는 로그아웃시킨다(tokens 비움).
  def update_info
    signup_request = SignupRequest.find(params[:id])
    user = User.from_email(signup_request.email)
    return render_info_error('승인된 계정만 수정할 수 있어요.', :not_found) if user.blank?

    name = params[:name].to_s.strip
    email = params[:email].to_s.strip.downcase
    return render_info_error('이름을 입력해주세요.', :bad_request) if name.blank?
    return render_info_error('이메일 형식이 올바르지 않아요.', :bad_request) unless email.match?(URI::MailTo::EMAIL_REGEXP)
    return render_info_error('이미 다른 계정이 쓰고 있는 이메일이에요.', :conflict) if email_taken?(email, user, signup_request)

    temp_password = nil
    ActiveRecord::Base.transaction do
      user.name = name
      user.display_name = params[:display_name].to_s.strip.presence if params.key?(:display_name)
      merge_profile_attributes!(user, params)
      if email != user.email.to_s.downcase
        user.skip_reconfirmation!
        user.email = email
      end
      if ActiveModel::Type::Boolean.new.cast(params[:reset_password])
        temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
        user.password = temp_password
        user.password_confirmation = temp_password
        user.tokens = {}
      end
      user.save!
      signup_request.update!(name: name, email: email, display_name: user.display_name,
                             **PROFILE_KEYS.index_with { |key| user.custom_attributes[key.to_s] })
    end

    render json: { success: true, name: name, email: email, temp_password: temp_password }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'not_found' }, status: :not_found
  rescue ActiveRecord::RecordInvalid => e
    render_info_error(e.record.errors.full_messages.to_sentence, :unprocessable_entity)
  end

  def reject
    signup_request = SignupRequest.find(params[:id])
    signup_request.update!(status: :rejected, reviewed_at: Time.current)
    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'not_found' }, status: :not_found
  end

  # 계정을 이 워크스페이스에서 삭제한다: 해당 계정에 대한 접근 권한(AccountUser)만 없애고
  # User 자체는 남겨둔다 (다른 계정 소속일 수도 있고, 나중에 재가입하면 재사용됨).
  # SignupRequest 행도 지워서 목록에서 사라지게 한다 - 다시 로그인하면 새 대기 요청이 생긴다.
  def revoke
    signup_request = SignupRequest.find(params[:id])
    user = User.from_email(signup_request.email)
    AccountUser.where(account_id: signup_request.account_id, user_id: user.id).destroy_all if user.present?
    signup_request.destroy!

    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'not_found' }, status: :not_found
  end

  private

  PROFILE_KEYS = %i[phone_number department job_title].freeze

  # 연락처/부서/직책은 User#custom_attributes에 둔다(본인 프로필 화면과 같은 곳). 값이 들어온 항목만 바꾼다.
  def merge_profile_attributes!(user, source)
    updates = {}
    PROFILE_KEYS.each do |key|
      next unless source.respond_to?(:key?) && (source.key?(key) || source.key?(key.to_s))

      updates[key.to_s] = (source[key] || source[key.to_s]).to_s.strip.presence
    end
    return if updates.empty?

    user.update!(custom_attributes: user.custom_attributes.merge(updates).compact)
  end

  def merge_profile_from_user!(row, user)
    row['name'] = user.name
    row['display_name'] = user.display_name
    PROFILE_KEYS.each { |key| row[key.to_s] = user.custom_attributes[key.to_s] }
  end

  def application_attributes
    {
      email: params[:email].to_s.strip.downcase, name: params[:name].to_s.strip, password: params[:password].to_s,
      display_name: params[:display_name].to_s.strip.presence, phone_number: params[:phone_number].to_s.strip,
      department: params[:department].to_s.strip, job_title: params[:job_title].to_s.strip.presence
    }
  end

  def application_errors(attrs)
    errors = []
    errors << '이메일 형식이 올바르지 않아요.' unless attrs[:email].match?(URI::MailTo::EMAIL_REGEXP)
    errors << '이름을 입력해주세요.' if attrs[:name].blank?
    errors << '연락처를 입력해주세요.' if attrs[:phone_number].blank?
    errors << '부서를 입력해주세요.' if attrs[:department].blank?
    errors << '비밀번호가 확인과 달라요.' if params[:password_confirmation].to_s != attrs[:password]
    errors.concat(password_errors(attrs))
  end

  # 사용자 모델의 비밀번호 규칙(길이, 대/소문자·숫자·특수문자 각 1개 이상)을 그대로 쓴다.
  def password_errors(attrs)
    candidate = User.new(email: attrs[:email], name: attrs[:name].presence || 'x', password: attrs[:password], password_confirmation: attrs[:password])
    candidate.valid?
    messages = candidate.errors[:password]
    messages.any? ? ["비밀번호가 규칙에 맞지 않아요 (6자 이상, 대문자·소문자·숫자·특수문자를 각각 1개 이상 포함)."] : []
  end

  def render_info_error(message, status)
    render json: { success: false, error: message }, status: status
  end

  def email_taken?(email, user, signup_request)
    return false if email == user.email.to_s.downcase

    User.from_email(email).present? || SignupRequest.where.not(id: signup_request.id).exists?(email: email)
  end

  def valid_level(raw)
    LEVELS.include?(raw) ? raw : 'operator'
  end

  def apply_level!(signup_request, level)
    account = Account.find(signup_request.account_id)
    user = User.from_email(signup_request.email)

    if user.blank?
      temp_password = "1!aA#{SecureRandom.alphanumeric(12)}"
      user = User.new(
        email: signup_request.email,
        name: signup_request.name.presence || signup_request.email.split('@').first,
        display_name: signup_request.display_name.presence,
        password: temp_password,
        password_confirmation: temp_password
      )
      user.skip_confirmation!
      user.save!
      # 신청 화면에서 정한 비밀번호가 있으면 (해시 그대로) 적용, 없으면(구글 가입 등) 위 임시 비밀번호가 남는다
      user.update_column(:encrypted_password, signup_request.encrypted_password) if signup_request.encrypted_password.present?
      merge_profile_attributes!(user, signup_request.attributes.symbolize_keys)
      Avatar::AvatarFromUrlJob.perform_later(user, signup_request.avatar_url) if signup_request.avatar_url.present?
    end

    chatwoot_role = level == 'operator' ? 'agent' : 'administrator'
    account_user = AccountUser.find_by(account_id: account.id, user_id: user.id)
    account_user ||= AccountUser.create!(account_id: account.id, user_id: user.id, role: chatwoot_role)
    account_user.update!(role: chatwoot_role) if account_user.role != chatwoot_role

    user.update!(custom_attributes: user.custom_attributes.merge('cx_admin_level' => level))
  end
end
