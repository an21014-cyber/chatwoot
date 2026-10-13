<script setup>
defineProps({
  text: { type: String, default: '' },
});
</script>

<template>
  <div class="px-4 pt-1 pb-2 bg-n-slate-2 dark:bg-n-solid-1">
    <div
      class="inline-flex items-center gap-2 px-3 py-1.5 rounded-full text-xs font-medium bg-n-background dark:bg-n-solid-3 text-n-slate-11 shadow-[0_1px_2px_rgba(16,24,40,0.06)]"
    >
      <span
        class="h-1.5 w-1.5 rounded-full shrink-0"
        style="background-color: var(--widget-color, #2F6FED);"
      />
      <span>{{ text }}</span>
    </div>
  </div>
</template>
