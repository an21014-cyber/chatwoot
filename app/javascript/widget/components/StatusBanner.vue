<script setup>
defineProps({
  text: { type: String, default: '' },
});
</script>

<template>
  <div
    class="flex items-center gap-2 w-full px-5 py-2 text-xs font-medium bg-n-slate-3 dark:bg-n-solid-2 text-n-slate-11"
  >
    <span
      class="h-1.5 w-1.5 rounded-full shrink-0"
      style="background-color: var(--widget-color, #1f93ff);"
    />
    <span>{{ text }}</span>
  </div>
</template>
