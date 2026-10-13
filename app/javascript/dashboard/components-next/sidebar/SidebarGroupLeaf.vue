<script setup>
import { isVNode, computed } from 'vue';
import Icon from 'next/icon/Icon.vue';
import Policy from 'dashboard/components/policy.vue';
import { useSidebarContext } from './provider';
import SidebarUnreadBadge from './SidebarUnreadBadge.vue';
import { toneClass } from './sidebarTone';

const props = defineProps({
  name: { type: String, default: '' },
  label: { type: String, required: true },
  to: { type: [String, Object], required: true },
  icon: { type: [String, Object], default: null },
  active: { type: Boolean, default: false },
  component: { type: Function, default: null },
  badgeCount: { type: [Number, String], default: 0 },
  hideTreeLine: { type: Boolean, default: false },
  thinTreeLine: { type: Boolean, default: false },
});

const { resolvePermissions, resolveFeatureFlag } = useSidebarContext();

const shouldRenderComponent = computed(() => {
  return typeof props.component === 'function' || isVNode(props.component);
});

// Tree-line connector per leaf: vertical line (::before) + rounded elbow on the
// last child (::after). Logical props (start / border-s / rounded-es)
const TREE_CONNECTOR =
  "child-item before:content-[''] before:absolute before:start-0 before:w-0.5 before:h-full before:bg-n-slate-4 first:before:rounded-t last:before:h-1/5 last:after:content-[''] last:after:absolute last:after:start-0 last:after:bottom-[calc(50%_-_2px)] last:after:h-3 last:after:w-2.5 last:after:border-b-2 last:after:border-s-2 last:after:rounded-es last:after:border-n-slate-4";
</script>

<template>
  <Policy
    :permissions="resolvePermissions(to)"
    :feature-flag="resolveFeatureFlag(to)"
    as="li"
    class="py-0.5 ps-2 ms-3 relative text-n-slate-11 min-w-0"
    :class="{
      [TREE_CONNECTOR]: !hideTreeLine,
      'before:!w-px last:after:!border-b last:after:!border-s':
        !hideTreeLine && thinTreeLine,
    }"
  >
    <component
      :is="to ? 'router-link' : 'div'"
      :to="to"
      :title="label"
      class="flex h-9 items-center gap-2 px-2.5 py-1 rounded-xl transition-colors hover:bg-[color-mix(in_srgb,#2F6FED_7%,transparent)] dark:hover:bg-[color-mix(in_srgb,#6A97F4_12%,transparent)] group min-w-0"
      :class="{
        'bg-[color-mix(in_srgb,#2F6FED_12%,transparent)] dark:bg-[color-mix(in_srgb,#6A97F4_18%,transparent)] text-[#2F6FED] dark:text-[#9DBBF8] font-semibold active': active,
      }"
    >
      <component
        :is="component"
        v-if="shouldRenderComponent"
        v-bind="{ label, icon, active, badgeCount }"
      />
      <template v-else>
        <span
          v-if="icon"
          class="size-6 grid place-content-center rounded-md flex-shrink-0"
          :class="toneClass(name)"
        >
          <Icon :icon="icon" class="size-3.5 inline-block" />
        </span>
        <div class="flex-1 truncate min-w-0 text-sm">{{ label }}</div>
        <SidebarUnreadBadge :count="badgeCount" />
      </template>
    </component>
  </Policy>
</template>
