# CX POC 커스텀 컨트롤러.
# 봇이 상담 워크플로우 폼에서 받은 고객 이름/연락처를 Contact 레코드에 반영하는 용도.
# 공개 Agent Bot API(api_access_token)는 contacts#update를 화이트리스트에 넣어두지 않아서
# (AccessTokenAuthHelper::BOT_ACCESSIBLE_ENDPOINTS) 봇 토큰으로는 호출이 막혀있다 - 그래서
# 가입 승인 큐와 같은 방식(도커 내부망 전용, 공유 비밀 헤더)으로 이 경로를 대신 쓴다.
class Internal::ContactsController < Internal::BaseController
  def update
    contact = Contact.find_by(id: params[:id], account_id: params[:account_id])
    return render json: { success: false, error: 'not_found' }, status: :not_found unless contact

    contact.update!(permitted_params)
    render json: { success: true, id: contact.id, name: contact.name, phone_number: contact.phone_number }
  rescue ActiveRecord::RecordInvalid => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  private

  def permitted_params
    params.permit(:name, :phone_number)
  end
end
