class Api::V1::Accounts::CannedResponsesController < Api::V1::Accounts::BaseController
  before_action :fetch_canned_response, only: [:update, :destroy]

  def index
    render json: canned_responses.includes(:created_by, :updated_by)
  end

  def create
    @canned_response = Current.account.canned_responses.new(
      canned_response_params.merge(created_by_id: cx_actor_id, updated_by_id: cx_actor_id)
    )
    @canned_response.save!
    render json: @canned_response
  end

  def update
    @canned_response.update!(canned_response_params.merge(updated_by_id: cx_actor_id))
    render json: @canned_response
  end

  def destroy
    @canned_response.destroy!
    head :ok
  end

  private

  # CX POC 커스텀: 변경한 사람 기록 (봇/API 토큰 등 사람 계정이 아닌 경우는 기록하지 않음)
  def cx_actor_id
    Current.user.is_a?(User) ? Current.user.id : nil
  end

  def fetch_canned_response
    @canned_response = Current.account.canned_responses.find(params[:id])
  end

  def canned_response_params
    params.require(:canned_response).permit(:short_code, :content)
  end

  def canned_responses
    if params[:search]
      search = params[:search].delete("\0")
      Current.account.canned_responses
             .where('short_code ILIKE :search OR content ILIKE :search', search: "%#{search}%")
             .order_by_search(search)

    else
      Current.account.canned_responses
    end
  end
end
