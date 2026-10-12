# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password, :secret, :_key, :auth, :crypt, :salt, :certificate, :otp, :access, :private, :protected, :ssn,
  :otp_secret, :otp_code, :backup_code, :mfa_token, :otp_backup_codes
]

# Regex to filter all occurrences of 'token' in keys except for 'website_token'
filter_regex = /\A(?!.*\bwebsite_token\b).*token/i

# Apply the regex for filtering
Rails.application.config.filter_parameters += [filter_regex]

# CX POC 커스텀: 고객 개인정보(메시지 본문, 연락처, 이메일, 폼 제출값, 고객/대화 속성)가
# 서버 로그에 평문으로 남지 않게 한다. 로그에서 값만 [FILTERED]로 보이고 동작에는 영향이 없다.
# 키 이름이 정확히 일치할 때만 가린다(content_type 같은 디버깅용 키는 그대로 둠) - 중첩된 키는
# 'message.content'처럼 점으로 이어진 경로로 비교되므로 앞부분은 (\A|\.)로 받는다.
Rails.application.config.filter_parameters += [
  /(\A|\.)(content|phone_number|email|custom_attributes|additional_attributes|submitted_values)\z/
]
