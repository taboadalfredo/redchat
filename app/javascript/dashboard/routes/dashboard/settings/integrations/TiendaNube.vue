<script setup>
import { ref, computed, onMounted } from 'vue';
import {
  useFunctionGetter,
  useMapGetter,
  useStore,
} from 'dashboard/composables/store';
import Integration from './Integration.vue';
import Spinner from 'shared/components/Spinner.vue';
import integrationAPI from 'dashboard/api/integrations';

import Input from 'dashboard/components-next/input/Input.vue';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import Button from 'dashboard/components-next/button/Button.vue';

const store = useStore();
const dialogRef = ref(null);
const integrationLoaded = ref(false);
const authCode = ref('');
const isSubmitting = ref(false);
const authCodeError = ref('');
const integration = useFunctionGetter('integrations/getIntegration', 'tiendanube');
const uiFlags = useMapGetter('integrations/getUIFlags');

const integrationAction = computed(() => {
  if (integration.value.enabled) {
    return 'disconnect';
  }
  return 'connect';
});

const hideAuthCodeModal = () => {
  authCode.value = '';
  authCodeError.value = '';
  isSubmitting.value = false;
};

const validateAuthCode = code => {
  // TiendaNube auth codes are hexadecimal strings
  const pattern = /^[a-fA-F0-9]{20,}$/;
  return pattern.test(code);
};

const openAuthCodeDialog = () => {
  if (dialogRef.value) {
    dialogRef.value.open();
  }
};

const handleAuthCodeSubmit = async () => {
  try {
    authCodeError.value = '';
    if (!validateAuthCode(authCode.value)) {
      authCodeError.value =
        'Please enter a valid authorization code from Tienda Nube';
      return;
    }

    isSubmitting.value = true;
    await integrationAPI.connectTiendaNube({
      code: authCode.value,
    });

    await store.dispatch('integrations/get', 'tiendanube');
    hideAuthCodeModal();
    dialogRef.value?.close();
  } catch (error) {
    authCodeError.value = error.response?.data?.error || error.message;
  } finally {
    isSubmitting.value = false;
  }
};

const initializeTiendaNubeIntegration = async () => {
  await store.dispatch('integrations/get', 'tiendanube');
  integrationLoaded.value = true;
};

onMounted(() => {
  initializeTiendaNubeIntegration();
});
</script>

<template>
  <div class="flex-grow flex-shrink p-4 overflow-auto max-w-6xl mx-auto">
    <div
      v-if="integrationLoaded && !uiFlags.isCreatingTiendaNube"
      class="flex flex-col gap-6"
    >
      <Integration
        :integration-id="integration.id"
        :integration-logo="integration.logo"
        :integration-name="integration.name"
        :integration-description="integration.description"
        :integration-enabled="integration.enabled"
        :integration-action="integrationAction"
        :delete-confirmation-text="{
          title: $t('INTEGRATION_SETTINGS.TIENDANUBE.DELETE.TITLE'),
          message: $t('INTEGRATION_SETTINGS.TIENDANUBE.DELETE.MESSAGE'),
        }"
      >
        <template #action>
          <Button
            teal
            :label="$t('INTEGRATION_SETTINGS.CONNECT.BUTTON_TEXT')"
            @click="openAuthCodeDialog"
          />
        </template>
      </Integration>
      <Dialog
        ref="dialogRef"
        :title="$t('INTEGRATION_SETTINGS.TIENDANUBE.AUTH_CODE.TITLE')"
        :is-loading="isSubmitting"
        @confirm="handleAuthCodeSubmit"
        @close="hideAuthCodeModal"
      >
        <Input
          v-model="authCode"
          :label="$t('INTEGRATION_SETTINGS.TIENDANUBE.AUTH_CODE.LABEL')"
          :placeholder="
            $t('INTEGRATION_SETTINGS.TIENDANUBE.AUTH_CODE.PLACEHOLDER')
          "
          :message="
            !authCodeError
              ? $t('INTEGRATION_SETTINGS.TIENDANUBE.AUTH_CODE.HELP')
              : authCodeError
          "
          :message-type="authCodeError ? 'error' : 'info'"
        />
      </Dialog>
    </div>

    <div v-else class="flex items-center justify-center flex-1">
      <Spinner size="" color-scheme="primary" />
    </div>
  </div>
</template>
