<script lang="ts">
  import CircleIconButton from '$lib/components/elements/buttons/circle-icon-button.svelte';
  import CreateSharedLinkModal from '$lib/components/shared-components/create-share-link-modal/create-shared-link-modal.svelte';
  import { mdiShareVariantOutline } from '@mdi/js';
  import { createEventDispatcher } from 'svelte';
  import { getAssetControlContext } from '../asset-select-control-bar.svelte';

  let showModal = false;
  const dispatch = createEventDispatcher();
  const { getAssets } = getAssetControlContext();
  const escape = () => {
    dispatch('escape');
    showModal = false;
  };
</script>

<CircleIconButton title="Share" icon={mdiShareVariantOutline} on:click={() => (showModal = true)} />

{#if showModal}
  <CreateSharedLinkModal
    assetIds={Array.from(getAssets()).map(({ id }) => id)}
    on:close={() => (showModal = false)}
    on:escape={escape}
  />
{/if}
