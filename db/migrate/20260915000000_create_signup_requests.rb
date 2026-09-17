class CreateSignupRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :signup_requests do |t|
      t.string :email, null: false
      t.string :name
      t.string :avatar_url
      t.integer :status, default: 0, null: false # 0 pending / 1 approved / 2 rejected
      t.integer :account_id, null: false
      t.integer :reviewed_by_id
      t.datetime :reviewed_at

      t.timestamps
    end

    add_index :signup_requests, :email, unique: true
  end
end
