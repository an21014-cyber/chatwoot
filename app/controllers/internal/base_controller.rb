# CX POC 커스텀: 모든 internal/* 컨트롤러의 공통 인증 베이스.
# Devise 세션 인증을 거치지 않고, 공유 비밀 헤더(X-Internal-Token)로만 보호한다.
# 공개 인터넷(cloudflared)이 아니라 도커 내부망에서 bot-webhook 컨테이너가 호출하는 용도.
class Internal::BaseController < ActionController::Base
  skip_before_action :verify_authenticity_token, raise: false
  before_action :authenticate_internal_request!

  private

  def authenticate_internal_request!
    expected = ENV.fetch('INTERNAL_ADMIN_TOKEN', nil)
    provided = request.headers['X-Internal-Token']

    return if expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided.to_s)

    render json: { success: false, error: 'unauthorized' }, status: :unauthorized
  end
end
