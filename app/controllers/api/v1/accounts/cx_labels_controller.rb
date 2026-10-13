# CX POC 커스텀: 상담 종료 때 쓰는 "태그". Chatwoot 라벨(Label)을 태그로 쓰고, 종료 창에서 없는 태그를 바로 만들 수 있게 한다.
# 기본 라벨 생성 API(POST labels)는 관리자만 쓸 수 있어서, 상담원도 쓸 수 있는 "있으면 그대로, 없으면 생성" 엔드포인트를 둔다.
# 삭제·이름 변경은 기존 설정 > 라벨 화면(관리자)에서 한다.
class Api::V1::Accounts::CxLabelsController < Api::V1::Accounts::BaseController
  PALETTE = %w[#2F6FED #17935A #C77700 #D6314F #6B4FD8 #0E8A8F #5B6577 #E6732B].freeze

  def create
    title = normalize_title(params[:title])
    return render json: { error: '태그 이름을 입력해주세요.' }, status: :unprocessable_entity if title.blank?

    label = Current.account.labels.find_by(title: title) || create_label(title)
    render json: { id: label.id, title: label.title, color: label.color }
  rescue ActiveRecord::RecordInvalid => e
    existing = Current.account.labels.find_by(title: title)
    return render json: { id: existing.id, title: existing.title, color: existing.color } if existing

    render json: { error: e.record.errors.full_messages.to_sentence }, status: :unprocessable_entity
  end

  private

  # 라벨 이름 규칙(글자·숫자·하이픈·밑줄, 소문자)에 맞춘다: 공백은 하이픈으로, 그 밖의 기호는 뺀다 (화면의 normalize와 같은 규칙)
  def normalize_title(raw)
    raw.to_s.strip.downcase.gsub(/\s+/, '-').gsub(/[^\p{L}\p{N}\-_]/, '')[0, 40]
  end

  def create_label(title)
    Current.account.labels.create!(title: title, color: PALETTE[Current.account.labels.count % PALETTE.size], show_on_sidebar: false)
  end
end
