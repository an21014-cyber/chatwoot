<script>
import { useAlert } from 'dashboard/composables';
import NextButton from 'dashboard/components-next/button/Button.vue';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength, email } from '@vuelidate/validators';
export default {
  components: {
    NextButton,
  },
  props: {
    name: {
      type: String,
      default: '',
    },
    email: {
      type: String,
      default: '',
    },
    displayName: {
      type: String,
      default: '',
    },
    emailEnabled: {
      type: Boolean,
      default: false,
    },
    phoneNumber: { type: String, default: '' },
    department: { type: String, default: '' },
    jobTitle: { type: String, default: '' },
  },
  emits: ['updateUser'],
  setup() {
    return { v$: useVuelidate() };
  },
  data() {
    return {
      userName: this.name,
      userDisplayName: this.displayName,
      userEmail: this.email,
      userPhone: this.phoneNumber,
      userDepartment: this.department,
      userJobTitle: this.jobTitle,
      inputStyles: {
        borderRadius: '0.75rem',
        padding: '0.375rem 0.75rem',
        fontSize: '0.875rem',
        marginBottom: '0.125rem',
      },
    };
  },
  validations: {
    userName: {
      required,
      minLength: minLength(1),
    },
    userDisplayName: {},
    userEmail: {
      required,
      email,
    },
  },
  watch: {
    name: {
      handler(value) {
        this.userName = value;
      },
      immediate: true,
    },
    displayName: {
      handler(value) {
        this.userDisplayName = value;
      },
      immediate: true,
    },
    email: {
      handler(value) {
        this.userEmail = value;
      },
      immediate: true,
    },
    phoneNumber: {
      handler(value) {
        this.userPhone = value;
      },
      immediate: true,
    },
    department: {
      handler(value) {
        this.userDepartment = value;
      },
      immediate: true,
    },
    jobTitle: {
      handler(value) {
        this.userJobTitle = value;
      },
      immediate: true,
    },
  },
  methods: {
    async updateUser() {
      this.v$.$touch();
      if (this.v$.$invalid) {
        useAlert(this.$t('PROFILE_SETTINGS.FORM.ERROR'));
        return;
      }
      this.$emit('updateUser', {
        name: this.userName,
        displayName: this.userDisplayName,
        email: this.userEmail,
        phone_number: this.userPhone,
        department: this.userDepartment,
        job_title: this.userJobTitle,
      });
    },
  },
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="updateUser('profile')">
    <woot-input
      v-model="userName"
      :styles="inputStyles"
      :class="{ error: v$.userName.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.NAME.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.NAME.PLACEHOLDER')"
      :error="`${
        v$.userName.$error ? $t('PROFILE_SETTINGS.FORM.NAME.ERROR') : ''
      }`"
      @input="v$.userName.$touch"
      @blur="v$.userName.$touch"
    />
    <woot-input
      v-model="userDisplayName"
      :styles="inputStyles"
      :class="{ error: v$.userDisplayName.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.PLACEHOLDER')"
      :error="`${
        v$.userDisplayName.$error
          ? $t('PROFILE_SETTINGS.FORM.DISPLAY_NAME.ERROR')
          : ''
      }`"
      @input="v$.userDisplayName.$touch"
      @blur="v$.userDisplayName.$touch"
    />
    <woot-input
      v-if="emailEnabled"
      v-model="userEmail"
      :styles="inputStyles"
      :class="{ error: v$.userEmail.$error }"
      :label="$t('PROFILE_SETTINGS.FORM.EMAIL.LABEL')"
      :placeholder="$t('PROFILE_SETTINGS.FORM.EMAIL.PLACEHOLDER')"
      :error="`${
        v$.userEmail.$error ? $t('PROFILE_SETTINGS.FORM.EMAIL.ERROR') : ''
      }`"
      @input="v$.userEmail.$touch"
      @blur="v$.userEmail.$touch"
    />
    <!-- CX POC 커스텀: 팀원 프로필(연락처/부서/직책) - 본인이 직접 수정, 슈퍼어드민은 관리자 메뉴에서 전체 수정 -->
    <woot-input
      v-model="userPhone"
      :styles="inputStyles"
      label="연락처"
      placeholder="010-1234-5678"
    />
    <woot-input
      v-model="userDepartment"
      :styles="inputStyles"
      label="부서"
      placeholder="예: 운영기획팀"
    />
    <woot-input
      v-model="userJobTitle"
      :styles="inputStyles"
      label="직책"
      placeholder="예: 매니저"
    />
    <div>
      <NextButton type="submit" :label="$t('PROFILE_SETTINGS.BTN_TEXT')" />
    </div>
  </form>
</template>
