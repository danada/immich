<script lang="ts">
  import { UserResponseDto, api } from '@api';
  import UserAvatar from '../shared-components/user-avatar.svelte';
  import Button from '../elements/buttons/button.svelte';
  import PartnerSelectionModal from './partner-selection-modal.svelte';
  import { handleError } from '../../utils/handle-error';
  import ConfirmDialogue from '../shared-components/confirm-dialogue.svelte';
  import CircleIconButton from '../elements/buttons/circle-icon-button.svelte';
  import { mdiClose } from '@mdi/js';

  export let user: UserResponseDto;

  export let partners: UserResponseDto[];
  let createPartner = false;
  let removePartner: UserResponseDto | null = null;

  const refreshPartners = async () => {
    const { data } = await api.partnerApi.getPartners({ direction: 'shared-by' });
    partners = data;
  };

  const handleRemovePartner = async () => {
    if (!removePartner) {
      return;
    }

    try {
      await api.partnerApi.removePartner({ id: removePartner.id });
      removePartner = null;
      await refreshPartners();
    } catch (error) {
      handleError(error, 'Unable to remove partner');
    }
  };

  const handleCreatePartners = async (users: UserResponseDto[]) => {
    try {
      for (const user of users) {
        await api.partnerApi.createPartner({ id: user.id });
      }

      await refreshPartners();
      createPartner = false;
    } catch (error) {
      handleError(error, 'Unable to add partners');
    }
  };
</script>

<section class="my-4">
  {#if partners.length > 0}
    <div class="flex flex-row gap-4">
      {#each partners as partner (partner.id)}
        <div class="flex gap-4 rounded-lg px-5 py-4 transition-all">
          <UserAvatar user={partner} size="md" autoColor />
          <div class="text-left">
            <p class="text-immich-fg dark:text-immich-dark-fg">
              {partner.firstName}
              {partner.lastName}
            </p>
            <p class="text-xs text-immich-fg/75 dark:text-immich-dark-fg/75">
              {partner.email}
            </p>
          </div>
          <CircleIconButton
            on:click={() => (removePartner = partner)}
            icon={mdiClose}
            size={'16'}
            title="Remove partner"
          />
        </div>
      {/each}
    </div>
  {/if}
  <div class="flex justify-end">
    <Button size="sm" on:click={() => (createPartner = true)}>Add partner</Button>
  </div>
</section>

{#if createPartner}
  <PartnerSelectionModal
    {user}
    on:close={() => (createPartner = false)}
    on:add-users={(event) => handleCreatePartners(event.detail)}
  />
{/if}

{#if removePartner}
  <ConfirmDialogue
    title="Stop sharing your photos?"
    prompt="{removePartner.firstName} will no longer be able to access your photos."
    on:cancel={() => (removePartner = null)}
    on:confirm={() => handleRemovePartner()}
  />
{/if}
