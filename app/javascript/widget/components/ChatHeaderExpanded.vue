<script setup>
import HeaderActions from './HeaderActions.vue';
import FluentIcon from 'shared/components/FluentIcon/Index.vue';
import { useMessageFormatter } from 'shared/composables/useMessageFormatter';

defineProps({
  avatarUrl: {
    type: String,
    default: '',
  },
  introHeading: {
    type: String,
    default: '',
  },
  introBody: {
    type: String,
    default: '',
  },
  showPopoutButton: {
    type: Boolean,
    default: false,
  },
});

const { formatMessage } = useMessageFormatter();
</script>

<template>
  <header
    class="header-expanded pt-6 pb-4 px-5 relative box-border w-full"
    style="background: linear-gradient(135deg, rgba(0,0,0,0) 0%, rgba(0,0,0,0.35) 100%), var(--widget-color, #1f93ff);"
  >
    <div class="flex items-start justify-between">
      <div
        class="h-12 w-12 rounded-full bg-white shadow-sm ring-2 ring-white/40 flex items-center justify-center overflow-hidden"
      >
        <img
          v-if="avatarUrl"
          class="h-full w-full object-cover"
          :src="avatarUrl"
          alt="Avatar"
        />
        <FluentIcon v-else icon="chat" size="22" class="text-n-slate-12" />
      </div>
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
        light
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="mt-4 text-2xl mb-1.5 font-medium text-white line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="text-lg leading-normal text-white/85 [&_a]:underline [&_a]:text-white line-clamp-6"
    />
  </header>
</template>
