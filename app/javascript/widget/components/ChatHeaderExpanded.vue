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
    class="header-expanded pt-6 pb-9 px-5 relative box-border w-full"
    style="background: linear-gradient(165deg, var(--widget-color, #2F6FED) 0%, color-mix(in srgb, var(--widget-color, #2F6FED) 68%, #0b1220) 100%);"
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
        <FluentIcon v-else icon="chat" size="22" class="text-[#1c2024]" />
      </div>
      <HeaderActions
        :show-popout-button="showPopoutButton"
        :show-end-conversation-button="false"
        light
      />
    </div>
    <h2
      v-dompurify-html="introHeading"
      class="mt-4 text-[22px] mb-1.5 font-bold tracking-tight text-white line-clamp-4"
    />
    <p
      v-dompurify-html="formatMessage(introBody)"
      class="text-[15px] leading-relaxed text-white/90 [&_a]:underline [&_a]:text-white line-clamp-6"
    />
    <!-- 본문 시트가 헤더 위로 둥글게 올라오는 곡선 (색은 본문 배경과 같아야 함) -->
    <div
      class="absolute inset-x-0 bottom-0 h-4 rounded-t-[22px] bg-n-slate-2 dark:bg-n-solid-1"
      aria-hidden="true"
    />
  </header>
</template>
