<script setup>
import { toRef } from 'vue';
import { useRouter } from 'vue-router';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import HeaderActions from './HeaderActions.vue';
import AvailabilityContainer from 'widget/components/Availability/AvailabilityContainer.vue';
import { useAvailability } from 'widget/composables/useAvailability';

const props = defineProps({
  avatarUrl: { type: String, default: '' },
  title: { type: String, default: '' },
  showPopoutButton: { type: Boolean, default: false },
  showBackButton: { type: Boolean, default: false },
  availableAgents: { type: Array, default: () => [] },
});

const availableAgents = toRef(props, 'availableAgents');

const router = useRouter();
const { isOnline } = useAvailability(availableAgents);

const onBackButtonClick = () => {
  router.replace({ name: 'home' });
};
</script>

<template>
  <header
    class="relative flex justify-between w-full px-5 pt-5 pb-8 gap-2"
    style="background: linear-gradient(165deg, var(--widget-color, #2F6FED) 0%, color-mix(in srgb, var(--widget-color, #2F6FED) 68%, #0b1220) 100%);"
  >
    <div class="flex items-center min-w-0">
      <button
        v-if="showBackButton"
        class="px-2 ltr:-ml-3 rtl:-mr-3"
        @click="onBackButtonClick"
      >
        <FluentIcon icon="chevron-left" size="24" class="text-white" />
      </button>
      <div class="relative shrink-0 ltr:mr-3 rtl:ml-3">
        <div
          class="w-10 h-10 rounded-full bg-white shadow-sm ring-2 ring-white/40 flex items-center justify-center overflow-hidden"
        >
          <img
            v-if="avatarUrl"
            class="w-full h-full object-cover"
            :src="avatarUrl"
            alt="avatar"
          />
          <FluentIcon v-else icon="chat" size="18" class="text-[#1c2024]" />
        </div>
        <div
          v-if="isOnline"
          class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full bg-n-teal-10"
          style="box-shadow: 0 0 0 2px var(--widget-color, #1f93ff);"
        />
      </div>
      <div class="flex flex-col gap-0.5 min-w-0">
        <div
          class="flex items-center text-[17px] font-bold leading-5 tracking-tight text-white truncate"
        >
          <span v-dompurify-html="title" class="ltr:mr-1 rtl:ml-1 truncate" />
        </div>
        <AvailabilityContainer
          :agents="availableAgents"
          :show-header="false"
          :show-avatars="false"
          text-classes="text-[12.5px] leading-4 text-white/90"
        />
      </div>
    </div>
    <HeaderActions :show-popout-button="showPopoutButton" light />
    <!-- 본문 시트가 헤더 위로 둥글게 올라오는 곡선 (색은 본문 배경과 같아야 함) -->
    <div
      class="absolute inset-x-0 bottom-0 h-4 rounded-t-[22px] bg-n-slate-2 dark:bg-n-solid-1"
      aria-hidden="true"
    />
  </header>
</template>
