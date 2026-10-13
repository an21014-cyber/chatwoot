# CX POC 커스텀: 가입 신청 화면에서 받은 프로필과 (해시된) 비밀번호를 승인될 때까지 보관한다.
# encrypted_password는 평문이 아니라 Devise 해시이고, 승인되면 사용자에게 옮긴 뒤 비운다.
class AddProfileToSignupRequests < ActiveRecord::Migration[7.2]
  def change
    add_column :signup_requests, :display_name, :string
    add_column :signup_requests, :phone_number, :string
    add_column :signup_requests, :department, :string
    add_column :signup_requests, :job_title, :string
    add_column :signup_requests, :encrypted_password, :string
  end
end
