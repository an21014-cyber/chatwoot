class Api::V1::Accounts::BulkActionsController < Api::V1::Accounts::BaseController
  before_action :cx_require_tags_for_bulk_resolve, only: [:create]

  def create
    case normalized_type
    when 'Conversation'
      enqueue_conversation_job
      head :ok
    when 'Contact'
      check_authorization_for_contact_action
      enqueue_contact_job
      head :ok
    else
      render json: { success: false }, status: :unprocessable_entity
    end
  end

  private

  # CX POC 커스텀: 여러 대화를 한 번에 종료할 때도 태그가 없는 대화가 섞여 있으면 막는다 (개별 종료 창에서 태그를 넣게 안내).
  def cx_require_tags_for_bulk_resolve
    return unless normalized_type == 'Conversation' && params.dig(:fields, :status).to_s == 'resolved'

    untagged = @current_account.conversations.where(display_id: Array(params[:ids])).reject { |c| c.label_list.present? }
    return if untagged.empty?

    render json: { error: "태그가 없는 대화가 #{untagged.size}건 있어요. 하나씩 종료하면서 태그를 넣어주세요.", code: 'cx_tags_required' },
           status: :unprocessable_entity
  end

  def normalized_type
    params[:type].to_s.camelize
  end

  def enqueue_conversation_job
    ::BulkActionsJob.perform_later(
      account: @current_account,
      user: current_user,
      params: conversation_params
    )
  end

  def enqueue_contact_job
    Contacts::BulkActionJob.perform_later(
      @current_account.id,
      current_user.id,
      contact_params
    )
  end

  def delete_contact_action?
    params[:action_name] == 'delete'
  end

  def check_authorization_for_contact_action
    authorize(Contact, :destroy?) if delete_contact_action?
  end

  def conversation_params
    # TODO: Align conversation payloads with the `{ action_name, action_attributes }`
    # and then remove this method in favor of a common params method.
    base = params.permit(
      :snoozed_until,
      fields: [:status, :assignee_id, :team_id]
    )
    append_common_bulk_attributes(base)
  end

  def contact_params
    # TODO: remove this method in favor of a common params method.
    # once legacy conversation payloads are migrated.
    append_common_bulk_attributes({})
  end

  def append_common_bulk_attributes(base_params)
    # NOTE: Conversation payloads historically diverged per action. Going forward we
    # want all objects to share a common contract: `{ action_name, action_attributes }`
    common = params.permit(:type, :action_name, ids: [], labels: [add: [], remove: []])
    base_params.merge(common)
  end
end
