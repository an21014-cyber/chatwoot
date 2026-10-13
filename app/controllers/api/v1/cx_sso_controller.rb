# CX POC 커스텀: 상담원 화면 안에 임베드되는 봇 관리 화면(관리자 메뉴, 예약정보 카드)용 로그인 연동.
# 비밀번호(Basic Auth) 대신, 지금 Chatwoot에 로그인한 사용자의 정보(누구인지/어떤 레벨인지)를 짧게 유효한
# 서명 값으로 만들어 준다. bot-webhook이 같은 비밀(INTERNAL_ADMIN_TOKEN)로 서명을 검증하고 레벨별로 권한을 검사한다.
#
# 토큰 형식: "v1.<payload(base64url JSON)>.<HMAC-SHA256 hex>"
#   payload = { uid, email, role(administrator|agent), lvl(super_admin|admin|operator), exp(epoch 초) }
#   서명 키 = "cx-sso:" + INTERNAL_ADMIN_TOKEN, 서명 대상 = "v1.<payload>"
# (webhook_bot.py의 verify_cx_token과 항상 같은 규칙으로 맞춰둘 것)
class Api::V1::CxSsoController < Api::BaseController
  TOKEN_TTL = 8.hours
  LEVELS = %w[super_admin admin operator].freeze

  def token
    account_user = current_user.account_users.find_by(account_id: params[:account_id])
    return render json: { error: 'forbidden' }, status: :forbidden if account_user.blank?

    secret = ENV.fetch('INTERNAL_ADMIN_TOKEN', '')
    return render json: { error: 'not_configured' }, status: :service_unavailable if secret.blank?

    expires_at = Time.zone.now + TOKEN_TTL
    payload = Base64.urlsafe_encode64(
      {
        uid: current_user.id, email: current_user.email, role: account_user.role,
        lvl: level_for(account_user), exp: expires_at.to_i
      }.to_json, padding: false
    )
    signature = OpenSSL::HMAC.hexdigest('SHA256', "cx-sso:#{secret}", "v1.#{payload}")
    render json: { token: "v1.#{payload}.#{signature}", expires_at: expires_at.to_i }
  end

  private

  # Chatwoot 기본 역할이 agent면 사용자 속성이 뭐든 오퍼레이터로 낮춘다(속성이 잘못 남아 있어도 권한이 올라가지 않게).
  # administrator인데 cx_admin_level이 비어 있으면(이 기능 이전 계정) 어드민으로 본다.
  def level_for(account_user)
    return 'operator' unless account_user.role == 'administrator'

    level = current_user.custom_attributes&.dig('cx_admin_level')
    LEVELS.include?(level) && level != 'operator' ? level : 'admin'
  end
end
