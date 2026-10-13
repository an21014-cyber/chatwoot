# == Schema Information
#
# Table name: canned_responses
#
#  id         :integer          not null, primary key
#  content    :text
#  short_code :string
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  account_id :integer          not null
#

class CannedResponse < ApplicationRecord
  include AccountCacheRevalidator

  validates :content, presence: true
  validates :short_code, presence: true
  validates :account, presence: true
  validates :short_code, uniqueness: { scope: :account_id }

  belongs_to :account
  # CX POC 커스텀: 만든 사람 / 마지막으로 수정한 사람 (예전에 만든 것·스크립트로 넣은 것은 nil = 시스템 등록)
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :updated_by, class_name: 'User', optional: true

  def as_json(options = {})
    super.merge(
      'created_by_name' => created_by&.name,
      'created_by_email' => created_by&.email,
      'updated_by_name' => updated_by&.name,
      'updated_by_email' => updated_by&.email
    )
  end

  scope :order_by_search, lambda { |search|
    short_code_starts_with = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 1', "#{search}%"])
    short_code_like = sanitize_sql_array(['WHEN short_code ILIKE ? THEN 0.5', "%#{search}%"])
    content_like = sanitize_sql_array(['WHEN content ILIKE ? THEN 0.2', "%#{search}%"])

    order_clause = "CASE #{short_code_starts_with} #{short_code_like} #{content_like} ELSE 0 END"

    order(Arel.sql(order_clause) => :desc)
  }
end
