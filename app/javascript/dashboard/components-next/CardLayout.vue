<script setup>
defineProps({
  layout: {
    type: String,
    default: 'col',
  },
  selectable: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['click']);

const handleClick = () => {
  emit('click');
};
</script>

<template>
  <div
    class="flex flex-col w-full outline-1 outline outline-n-container -outline-offset-1 group/cardLayout rounded-2xl bg-n-solid-2 shadow-[0_1px_3px_rgba(16,24,40,0.06)] transition-shadow hover:shadow-md"
  >
    <div
      class="flex w-full gap-3 py-5"
      :class="[
        layout === 'col' ? 'flex-col' : 'flex-row justify-between items-center',
        selectable ? 'px-10 py-6' : 'px-6',
      ]"
      @click="handleClick"
    >
      <slot />
    </div>

    <slot name="after" />
  </div>
</template>
