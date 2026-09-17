import { computed } from 'vue';
import { useStoreGetters } from 'dashboard/composables/store';

/**
 * Composable to determine if the current user is an administrator.
 * @returns {Boolean} - True if the current user is an administrator, false otherwise.
 */
export function useAdmin() {
  const getters = useStoreGetters();

  const currentUserRole = computed(() => getters.getCurrentRole.value);
  const isAdmin = computed(() => currentUserRole.value === 'administrator');

  // CX POC 커스텀: Chatwoot 기본 role(administrator/agent) 위에 3단계 권한을 추가
  // (User#custom_attributes.cx_admin_level: super_admin/admin/operator - 부여는
  // app/controllers/internal/signup_requests_controller.rb#apply_level! 참고).
  // "가입 승인 관리" 화면은 슈퍼어드민에게만 노출한다.
  const cxAdminLevel = computed(
    () => getters.getCurrentUser.value?.custom_attributes?.cx_admin_level
  );
  const isSuperAdmin = computed(() => cxAdminLevel.value === 'super_admin');

  return {
    isAdmin,
    isSuperAdmin,
  };
}
