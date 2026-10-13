class AddActorsToCannedResponses < ActiveRecord::Migration[7.1]
  # CX POC 커스텀: 단축 답변을 누가 만들고 마지막으로 고쳤는지 기록 (계정이 지워져도 행은 남도록 FK는 걸지 않음)
  def change
    add_column :canned_responses, :created_by_id, :integer
    add_column :canned_responses, :updated_by_id, :integer
  end
end
