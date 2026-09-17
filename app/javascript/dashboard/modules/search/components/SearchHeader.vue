<script setup>
import { ref, useTemplateRef } from 'vue';
import { FEATURE_FLAGS } from 'dashboard/featureFlags';
import { INSTALLATION_TYPES } from 'dashboard/constants/installationTypes';
import { ROLES } from 'dashboard/constants/permissions';

import SearchInput from './SearchInput.vue';
import SearchFilters from './SearchFilters.vue';
import SearchStatusSelector from './SearchStatusSelector.vue';
import Policy from 'dashboard/components/policy.vue';

const props = defineProps({
  initialQuery: { type: String, default: '' },
});

const emit = defineEmits(['search', 'filterChange']);

const filters = defineModel('filters', { type: Object, default: () => ({}) });

const searchInputRef = useTemplateRef('searchInputRef');
const searchQuery = ref(props.initialQuery);

const onSearch = query => {
  if (query?.trim() && searchInputRef.value) {
    searchInputRef.value.addToRecentSearches(query.trim());
  }
  emit('search', query);
};

const onSelectRecentSearch = query => {
  searchQuery.value = query;
  onSearch(query);
};

const onStatusChange = () => {
  emit('filterChange', filters.value);
};
</script>

<template>
  <div class="flex flex-col gap-2">
    <SearchInput
      ref="searchInputRef"
      v-model="searchQuery"
      @search="onSearch"
      @select-recent-search="onSelectRecentSearch"
    >
      <div class="flex items-center gap-1.5 px-4 pt-2">
        <SearchStatusSelector
          v-model="filters.status"
          :label="$t('SEARCH.FILTERS.STATUS')"
          @change="onStatusChange"
        />
      </div>
      <Policy
        :permissions="ROLES"
        :installation-types="[
          INSTALLATION_TYPES.ENTERPRISE,
          INSTALLATION_TYPES.CLOUD,
        ]"
        :feature-flag="FEATURE_FLAGS.ADVANCED_SEARCH"
        class="w-full"
      >
        <SearchFilters
          v-model="filters"
          @update-filters="$emit('filterChange', $event)"
        />
      </Policy>
    </SearchInput>
  </div>
</template>
