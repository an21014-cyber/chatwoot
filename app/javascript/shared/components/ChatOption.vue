<script>
import { mapGetters } from 'vuex';

export default {
  components: {},
  props: {
    action: {
      type: Object,
      default: () => {},
    },
    isSelected: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['optionSelect'],
  computed: {
    ...mapGetters({
      widgetColor: 'appConfig/getWidgetColor',
    }),
  },
  methods: {
    onClick() {
      this.$emit('optionSelect', this.action);
    },
  },
};
</script>

<template>
  <li class="option" :class="{ 'is-selected': isSelected }">
    <button
      class="option-button button"
      :style="{ '--opt': widgetColor }"
      @click="onClick"
    >
      <span>{{ action.title }}</span>
    </button>
  </li>
</template>

<style scoped lang="scss">
.option {
  @apply rounded-[5rem] ltr:float-left rtl:float-right m-1 max-w-full;

  .option-button {
    @apply border-0 cursor-pointer h-auto leading-normal ltr:text-left rtl:text-right whitespace-normal rounded-[5rem] min-h-[2.75rem] px-4 font-medium text-[14.5px];

    background: color-mix(in srgb, var(--opt, #2f6fed) 12%, transparent);
    color: var(--opt, #2f6fed);

    &:hover,
    &:focus {
      background: color-mix(in srgb, var(--opt, #2f6fed) 20%, transparent);
    }

    span {
      display: inline-block;
      vertical-align: middle;
    }
  }
}

// 다크모드: 어두운 배경에서도 읽히도록 글자색을 밝게, 바탕은 조금 진하게
:global(.dark) .option .option-button {
  background: color-mix(in srgb, var(--opt, #2f6fed) 30%, transparent);
  color: color-mix(in srgb, var(--opt, #2f6fed) 50%, white);
}
</style>
