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
    json = requests.as_json(only: [:id, :email, :name, :avatar_url, :status, :account_id, :created_at, :reviewed_at])
    json.each_with_index do |row, i|
      user = User.from_email(requests[i].email)
      row['level'] = user&.custom_attributes&.dig('cx_admin_level')
    end
    render json: json
  end

  def approve
    signup_request = SignupRequest.find(params[:id])
    level = valid_level(params[:level])

    apply_level!(signup_request, level)
    signup_request.update!(status: :approved, reviewed_at: Time.current)

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
        password: temp_password,
        password_confirmation: temp_password
      )
      user.skip_confirmation!
      user.save!
      Avatar::AvatarFromUrlJob.perform_later(user, signup_request.avatar_url) if signup_request.avatar_url.present?
    end

    chatwoot_role = level == 'operator' ? 'agent' : 'administrator'
    account_user = AccountUser.find_by(account_id: account.id, user_id: user.id)
    account_user ||= AccountUser.create!(account_id: account.id, user_id: user.id, role: chatwoot_role)
    account_user.update!(role: chatwoot_role) if account_user.role != chatwoot_role

    user.update!(custom_attributes: user.custom_attributes.merge('cx_admin_level' => level))
  end
end
