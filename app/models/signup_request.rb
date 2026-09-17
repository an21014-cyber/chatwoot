# == Schema Information
#
# Table name: signup_requests
#
#  id             :bigint           not null, primary key
#  avatar_url     :string
#  email          :string           not null
#  name           :string
#  reviewed_at    :datetime
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :integer          not null
#  reviewed_by_id :integer
#
# CX POC 전용: 구글 로그인으로 처음 들어온 사람을 바로 계정 생성하지 않고,
# 관리자 승인 대기 큐에 넣어두기 위한 모델 (app/controllers/devise_overrides/omniauth_callbacks_controller.rb 참고)
class SignupRequest < ApplicationRecord
  belongs_to :account
  belongs_to :reviewed_by, class_name: 'User', optional: true

  enum status: { pending: 0, approved: 1, rejected: 2 }

  validates :email, presence: true, uniqueness: true
end
