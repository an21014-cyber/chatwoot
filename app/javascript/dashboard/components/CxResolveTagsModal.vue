<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useStore } from 'vuex';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { cxResolveTagsState } from 'dashboard/composables/useCxResolveTags';

// CX POC 커스텀: 상담 종료 때 태그를 여러 개 넣는 창. 태그 = Chatwoot 라벨.
// - 이미 붙은 태그는 미리 채워져 있고(× 로 빼기), 입력 후 Enter/쉼표로 추가한다.
// - 목록에 없는 이름은 "새 태그"로 표시되고, 종료 시 자동으로 만들어진다(서버 CxLabelsController).
// - 태그가 1개 이상이어야 종료할 수 있다 (서버에서도 한 번 더 확인).
const store = useStore();
const { accountId } = useAccount();

const tags = ref([]);
const text = ref('');
const saving = ref(false);
const inputRef = ref(null);

const allLabels = computed(() => store.getters['labels/getLabels'] || []);

// 서버(Api::V1::Accounts::CxLabelsController#normalize_title)와 같은 규칙: 소문자, 공백은 하이픈, 글자·숫자·-·_ 만
const normalize = raw =>
  String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^\p{L}\p{N}\-_]/gu, '')
    .slice(0, 40);

const typed = computed(() => normalize(text.value));
const suggestions = computed(() =>
  allLabels.value
    .map(label => label.title)
    .filter(
      title =>
        !tags.value.includes(title) &&
        (!typed.value || title.includes(typed.value))
    )
    .slice(0, 16)
);
const isNewTag = computed(
  () =>
    typed.value &&
    !tags.value.includes(typed.value) &&
    !allLabels.value.some(label => label.title === typed.value)
);

watch(
  () => cxResolveTagsState.open,
  async open => {
    if (!open) return;
    tags.value = [...(cxResolveTagsState.conversation?.labels || [])];
    text.value = '';
    saving.value = false;
    store.dispatch('labels/get');
    await nextTick();
    inputRef.value?.focus();
  }
);

function close() {
  cxResolveTagsState.open = false;
  cxResolveTagsState.conversation = null;
  cxResolveTagsState.onDone = null;
}

function addTag(raw) {
  const name = normalize(raw);
  text.value = '';
  if (name && !tags.value.includes(name)) tags.value.push(name);
}

function removeTag(name) {
  tags.value = tags.value.filter(tag => tag !== name);
}

async function confirm() {
  if (text.value.trim()) addTag(text.value); // 입력하다 만 글자도 태그로 함께 넣는다
  if (!tags.value.length || saving.value) return;
  saving.value = true;
  try {
    const known = new Set(allLabels.value.map(label => label.title));
    for (const name of tags.value) {
      if (!known.has(name)) {
        // eslint-disable-next-line no-await-in-loop
        await window.axios.post(`/api/v1/accounts/${accountId.value}/cx_labels`, {
          title: name,
        });
      }
    }
    await store.dispatch('labels/get');
    await store.dispatch('conversationLabels/update', {
      conversationId: cxResolveTagsState.conversation.id,
      labels: tags.value,
    });
    const done = cxResolveTagsState.onDone;
    close();
    if (done) done();
  } catch (error) {
    useAlert('태그를 저장하지 못했어요. 다시 시도해주세요.');
    saving.value = false;
  }
}

function onKeydown(event) {
  if (event.isComposing) return; // 한글 입력 중 Enter는 글자 확정이라 건너뛴다
  if (event.key === 'Enter' || event.key === ',') {
    event.preventDefault();
    if (typed.value) addTag(text.value);
    else if (event.key === 'Enter' && tags.value.length) confirm();
  } else if (event.key === 'Backspace' && !text.value && tags.value.length) {
    tags.value.pop();
  } else if (event.key === 'Escape') {
    close();
  }
}
</script>

<template>
  <div
    v-if="cxResolveTagsState.open"
    class="fixed inset-0 z-[9999] flex items-center justify-center p-4 bg-black/50"
    @click.self="close"
  >
    <div
      class="w-full max-w-lg p-5 rounded-2xl shadow-xl bg-n-solid-2 text-n-slate-12 outline outline-1 outline-n-weak"
    >
      <h3 class="m-0 text-base font-bold">상담 종료 — 태그를 넣어주세요</h3>
      <p class="mt-1 mb-3 text-sm text-n-slate-11">
        이 상담을 설명하는 태그를 1개 이상 넣어주세요. 입력하고 Enter(또는
        쉼표)로 추가하면 되고, 목록에 없는 태그는 새로 만들어져요.
      </p>

      <div
        class="flex flex-wrap items-center gap-1.5 p-2 rounded-xl bg-n-alpha-1 outline outline-1 outline-n-weak"
        @click="inputRef?.focus()"
      >
        <span
          v-for="tag in tags"
          :key="tag"
          class="inline-flex items-center gap-1 px-2.5 py-1 text-sm font-medium rounded-full bg-n-blue-3 text-n-blue-11"
        >
          {{ tag }}
          <button
            type="button"
            class="leading-none opacity-70 hover:opacity-100"
            :title="`${tag} 빼기`"
            @click.stop="removeTag(tag)"
          >
            ✕
          </button>
        </span>
        <input
          ref="inputRef"
          v-model="text"
          type="text"
          class="flex-1 min-w-[8rem] !m-0 !p-1 !h-auto text-sm bg-transparent !border-0 !outline-none !shadow-none"
          placeholder="태그 입력 후 Enter"
          @keydown="onKeydown"
        />
      </div>

      <div class="mt-3 text-xs font-semibold text-n-slate-11">
        {{ typed ? '일치하는 태그' : '자주 쓰는 태그' }}
      </div>
      <div class="flex flex-wrap gap-1.5 mt-1.5 max-h-32 overflow-y-auto">
        <button
          v-if="isNewTag"
          type="button"
          class="px-2.5 py-1 text-sm font-medium rounded-full bg-n-teal-3 text-n-teal-11"
          @click="addTag(text)"
        >
          ＋ 새 태그 만들기: {{ typed }}
        </button>
        <button
          v-for="title in suggestions"
          :key="title"
          type="button"
          class="px-2.5 py-1 text-sm rounded-full bg-n-alpha-2 text-n-slate-12 hover:bg-n-alpha-3"
          @click="addTag(title)"
        >
          {{ title }}
        </button>
        <span
          v-if="!isNewTag && !suggestions.length"
          class="text-sm text-n-slate-10"
        >
          일치하는 태그가 없어요. 위에 입력해서 새로 만들 수 있어요.
        </span>
      </div>

      <div class="flex justify-end gap-2 mt-5">
        <button
          type="button"
          class="px-4 py-2 text-sm font-medium rounded-xl bg-n-alpha-2 hover:bg-n-alpha-3"
          @click="close"
        >
          취소
        </button>
        <button
          type="button"
          class="px-4 py-2 text-sm font-semibold text-white rounded-xl bg-n-brand disabled:opacity-50"
          :disabled="saving || (!tags.length && !typed)"
          @click="confirm"
        >
          {{ saving ? '저장 중…' : '태그 적용하고 종료' }}
        </button>
      </div>
    </div>
  </div>
</template>
