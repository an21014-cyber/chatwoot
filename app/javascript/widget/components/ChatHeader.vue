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
    class="flex justify-between w-full p-5 gap-2"
    style="background: linear-gradient(135deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.35) 100%), var(--widget-color, #1f93ff);"
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
          class="w-9 h-9 rounded-full bg-white shadow-sm ring-2 ring-white/40 flex items-center justify-center overflow-hidden"
        >
          <img
            v-if="avatarUrl"
            class="w-full h-full object-cover"
            :src="avatarUrl"
            alt="avatar"
          />
          <FluentIcon v-else icon="chat" size="18" class="text-n-slate-12" />
        </div>
        <div
          v-if="isOnline"
          class="absolute -bottom-0.5 -right-0.5 h-2.5 w-2.5 rounded-full bg-n-teal-10"
          style="box-shadow: 0 0 0 2px var(--widget-color, #1f93ff);"
        />
      </div>
      <div class="flex flex-col gap-0.5 min-w-0">
        <div
          class="flex items-center text-base font-medium leading-4 text-white truncate"
        >
          <span v-dompurify-html="title" class="ltr:mr-1 rtl:ml-1 truncate" />
        </div>
        <AvailabilityContainer
          :agents="availableAgents"
          :show-header="false"
          :show-avatars="false"
          text-classes="text-xs leading-3 text-white/80"
        />
      </div>
    </div>
    <HeaderActions :show-popout-button="showPopoutButton" light />
  </header>
</template>
