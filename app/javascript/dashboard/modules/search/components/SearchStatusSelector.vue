<script setup>
import { computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useToggle } from '@vueuse/core';
import { vOnClickOutside } from '@vueuse/components';
import DropdownMenu from 'dashboard/components-next/dropdown-menu/DropdownMenu.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
});

const emit = defineEmits(['change']);
const modelValue = defineModel({
  type: String,
  default: null,
});

const STATUSES = ['open', 'resolved', 'pending', 'snoozed'];

const { t } = useI18n();
const [showDropdown, toggleDropdown] = useToggle();

const statusLabel = status =>
  t(`CHAT_LIST.CHAT_STATUS_FILTER_ITEMS.${status}.TEXT`);

const menuSections = computed(() => [
  {
    items: STATUSES.map(status => ({
      label: statusLabel(status),
      value: status,
      action: 'select',
      isSelected: modelValue.value === status,
    })),
  },
]);

const selectedLabel = computed(() => {
  if (!modelValue.value) return props.label;
  return `${props.label}: ${statusLabel(modelValue.value)}`;
});

const handleAction = item => {
  modelValue.value = modelValue.value === item.value ? null : item.value;
  toggleDropdown(false);
  emit('change');
};
</script>

<template>
  <div
    v-on-click-outside="() => toggleDropdown(false)"
    class="relative flex items-center group min-w-0 max-w-full"
  >
    <Button
      sm
      :variant="showDropdown ? 'faded' : 'ghost'"
      slate
      :label="selectedLabel"
      trailing-icon
      icon="i-lucide-chevron-down"
      class="!px-2 max-w-full"
      @click="toggleDropdown()"
    />
    <DropdownMenu
      v-if="showDropdown"
      :menu-sections="menuSections"
      class="mt-1 ltr:right-0 rtl:left-0 top-full w-48"
      @action="handleAction"
    />
  </div>
</template>
