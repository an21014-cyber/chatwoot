class DeviseOverrides::OmniauthCallbacksController < DeviseTokenAuth::OmniauthCallbacksController
  include EmailHelper

  def omniauth_success
    get_resource_from_auth_hash

    @resource.present? ? sign_in_user : sign_up_user
  end

  private

  def sign_in_user
    # Capture before skip_confirmation! sets confirmed_at, which would
    # make oauth_user_needs_password_reset? return false and skip the
    # password reset for persisted unconfirmed users.
    needs_password_reset = oauth_user_needs_password_reset?
    @resource.skip_confirmation! if confirmable_enabled?
    set_random_password_if_oauth_user if needs_password_reset

    # once the resource is found and verified
    # we can just send them to the login page again with the SSO params
    # that will log them in
    encoded_email = ERB::Util.url_encode(@resource.email)
    redirect_to login_page_url(email: encoded_email, sso_auth_token: @resource.generate_sso_auth_token)
  end

  def sign_in_user_on_mobile
    # See comment in sign_in_user for why this is captured before skip_confirmation!
    needs_password_reset = oauth_user_needs_password_reset?
    @resource.skip_confirmation! if confirmable_enabled?
    set_random_password_if_oauth_user if needs_password_reset

    # once the resource is found and verified
    # we can just send them to the login page again with the SSO params
    # that will log them in
    encoded_email = ERB::Util.url_encode(@resource.email)
    params = { email: encoded_email, sso_auth_token: @resource.generate_sso_auth_token }.to_query

    mobile_deep_link_base = GlobalConfigService.load('MOBILE_DEEP_LINK_BASE', 'chatwootapp')
    redirect_to "#{mobile_deep_link_base}://auth/saml?#{params}", allow_other_host: true
  end

  # CX POC 커스텀: 새 이메일이 구글로 로그인하면 기존 create_account_for_user처럼
  # 곧바로 신규 계정을 만들어 관리자로 만들어버리지 않고, 지정된 회사 계정(account)에
  # 합류를 요청하는 SignupRequest를 만들고 "승인 대기" 안내만 보여준다.
  # 실제 계정 합류(User/AccountUser 생성)는 관리자가 승인할 때 별도로 처리된다.
  def sign_up_user
    return render_pending_page(html: business_domain_error_html) unless allowed_signup_email_domain?

    render_pending_page(html: pending_request_html(find_or_create_signup_request))
  end

  def login_page_url(error: nil, email: nil, sso_auth_token: nil)
    # CX POC 커스텀: FRONTEND_URL(고정값)이 아니라 지금 요청이 들어온 호스트를 그대로 써서
    # 리다이렉트를 만든다. 이 환경은 localhost:3000과 cloudflared 터널 주소를 오갈 수 있는데,
    # FRONTEND_URL 고정값을 쓰면 호스트가 달라져 Rails가 안전하지 않은 리다이렉트로 막아버리고,
    # 그렇다고 sso_auth_token이 담긴 리다이렉트를 allow_other_host로 강제로 열어버리는 건
    # 토큰이 다른 호스트로 샐 수 있는 위험이 있어 피한다. 같은 호스트로만 돌려보내면 안전하다.
    params = { email: email, sso_auth_token: sso_auth_token }.compact
    params[:error] = error if error.present?

    "#{request.base_url}/app/login?#{params.to_query}"
  end

  def account_signup_allowed?
    GlobalConfigService.account_signup_enabled?
  end

  def resource_class(_mapping = nil)
    User
  end

  def get_resource_from_auth_hash # rubocop:disable Naming/AccessorMethodName
    email = auth_hash.dig('info', 'email')
    @resource = resource_class.from_email(email)
  end

  def validate_signup_email_is_business_domain?
    # return true if the user is a business account, false if it is a blocked domain account
    Account::SignUpEmailValidationService.new(auth_hash['info']['email']).perform
  rescue CustomExceptions::Account::InvalidEmail
    false
  end

  def create_account_for_user
    @resource, @account = AccountBuilder.new(
      account_name: extract_domain_without_tld(auth_hash['info']['email']),
      user_full_name: auth_hash['info']['name'],
      email: auth_hash['info']['email'],
      locale: I18n.locale,
      confirmed: auth_hash['info']['email_verified']
    ).perform
    Avatar::AvatarFromUrlJob.perform_later(@resource, auth_hash['info']['image'])
  end

  def allowed_signup_email_domain?
    allowed_domain = ENV.fetch('SIGNUP_ALLOWED_EMAIL_DOMAIN', nil)
    return true if allowed_domain.blank?

    auth_hash.dig('info', 'email').to_s.downcase.end_with?("@#{allowed_domain.downcase}")
  end

  def find_or_create_signup_request
    target_account_id = ENV.fetch('SIGNUP_TARGET_ACCOUNT_ID', nil)
    email = auth_hash.dig('info', 'email')

    SignupRequest.find_by(email: email) || SignupRequest.create!(
      email: email,
      name: auth_hash.dig('info', 'name'),
      avatar_url: auth_hash.dig('info', 'image'),
      account_id: target_account_id
    )
  end

  def render_pending_page(html:)
    render inline: html, content_type: 'text/html', layout: false
  end

  def business_domain_error_html
    pending_page_shell(
      title: '가입할 수 없는 이메일입니다',
      message: '회사 이메일 계정으로만 가입 요청이 가능합니다. 담당자에게 문의해주세요.'
    )
  end

  def pending_request_html(signup_request)
    case signup_request.status
    when 'approved'
      pending_page_shell(
        title: '승인이 완료되었습니다',
        message: '가입이 승인되었어요. 로그인 화면으로 돌아가서 다시 "Google로 로그인"을 눌러주세요.'
      )
    when 'rejected'
      pending_page_shell(
        title: '가입 요청이 거절되었습니다',
        message: '관리자에게 문의해주세요.'
      )
    else
      pending_page_shell(
        title: '가입 승인 대기 중입니다',
        message: "#{signup_request.email} 계정으로 가입 요청이 접수되었습니다. 관리자가 승인하면 다시 로그인하실 수 있어요."
      )
    end
  end

  def pending_page_shell(title:, message:)
    <<~HTML
      <!DOCTYPE html>
      <html lang="ko"><head><meta charset="UTF-8"><title>#{title}</title>
      <style>
        body{font-family:-apple-system,"Malgun Gothic",sans-serif;background:#f5f7fa;display:flex;
             align-items:center;justify-content:center;height:100vh;margin:0;color:#222}
        .box{background:#fff;border-radius:12px;padding:36px 40px;box-shadow:0 2px 10px rgba(0,0,0,.08);
             max-width:420px;text-align:center}
        h1{font-size:19px;margin:0 0 12px}
        p{font-size:14px;color:#555;line-height:1.6;margin:0}
      </style></head>
      <body><div class="box"><h1>#{title}</h1><p>#{message}</p></div></body></html>
    HTML
  end

  def oauth_user_needs_password_reset?
    @resource.present? && (@resource.new_record? || !@resource.confirmed?)
  end

  def set_random_password_if_oauth_user
    # Password must satisfy secure_password requirements (uppercase, lowercase, number, special char)
    @resource.update(password: "#{SecureRandom.hex(16)}aA1!") if @resource.persisted?
  end

  def default_devise_mapping
    'user'
  end
end

DeviseOverrides::OmniauthCallbacksController.prepend_mod_with('DeviseOverrides::OmniauthCallbacksController')
