<script lang="ts">
  import UserPageLayout from '$lib/components/layouts/user-page-layout.svelte';
  import type { PageData } from './$types';
  import PeopleCard from '$lib/components/faces-page/people-card.svelte';
  import FullScreenModal from '$lib/components/shared-components/full-screen-modal.svelte';
  import Button from '$lib/components/elements/buttons/button.svelte';
  import { api, PeopleUpdateItem, type PersonResponseDto } from '@api';
  import { goto } from '$app/navigation';
  import { AppRoute } from '$lib/constants';
  import { handleError } from '$lib/utils/handle-error';
  import {
    NotificationType,
    notificationController,
  } from '$lib/components/shared-components/notification/notification';
  import ShowHide from '$lib/components/faces-page/show-hide.svelte';
  import IconButton from '$lib/components/elements/buttons/icon-button.svelte';
  import ImageThumbnail from '$lib/components/assets/thumbnail/image-thumbnail.svelte';
  import { onDestroy, onMount } from 'svelte';
  import { browser } from '$app/environment';
  import MergeSuggestionModal from '$lib/components/faces-page/merge-suggestion-modal.svelte';
  import SetBirthDateModal from '$lib/components/faces-page/set-birth-date-modal.svelte';
  import { shouldIgnoreShortcut } from '$lib/utils/shortcut';
  import { mdiAccountOff, mdiEyeOutline } from '@mdi/js';
  import Icon from '$lib/components/elements/icon.svelte';

  export let data: PageData;
  let selectHidden = false;
  let initialHiddenValues: Record<string, boolean> = {};

  let eyeColorMap: Record<string, 'black' | 'white'> = {};

  let people = data.people.people;
  let countTotalPeople = data.people.total;
  let countVisiblePeople = data.people.visible;

  let showLoadingSpinner = false;
  let toggleVisibility = false;

  let showChangeNameModal = false;
  let showSetBirthDateModal = false;
  let showMergeModal = false;
  let personName = '';
  let personMerge1: PersonResponseDto;
  let personMerge2: PersonResponseDto;
  let potentialMergePeople: PersonResponseDto[] = [];
  let edittingPerson: PersonResponseDto | null = null;

  people.forEach((person: PersonResponseDto) => {
    initialHiddenValues[person.id] = person.isHidden;
  });

  const onKeyboardPress = (event: KeyboardEvent) => handleKeyboardPress(event);

  onMount(() => {
    document.addEventListener('keydown', onKeyboardPress);
  });

  onDestroy(() => {
    if (browser) {
      document.removeEventListener('keydown', onKeyboardPress);
    }
  });

  const handleKeyboardPress = (event: KeyboardEvent) => {
    if (shouldIgnoreShortcut(event)) {
      return;
    }
    switch (event.key) {
      case 'Escape':
        handleCloseClick();
        return;
    }
  };

  const handleCloseClick = () => {
    for (const person of people) {
      person.isHidden = initialHiddenValues[person.id];
    }
    // trigger reactivity
    people = people;

    // Reset variables used on the "Show & hide faces"   modal
    showLoadingSpinner = false;
    selectHidden = false;
    toggleVisibility = false;
  };

  const handleResetVisibility = () => {
    for (const person of people) {
      person.isHidden = initialHiddenValues[person.id];
    }

    // trigger reactivity
    people = people;
  };

  const handleToggleVisibility = () => {
    toggleVisibility = !toggleVisibility;
    for (const person of people) {
      person.isHidden = toggleVisibility;
    }

    // trigger reactivity
    people = people;
  };

  const handleDoneClick = async () => {
    showLoadingSpinner = true;
    let changed: PeopleUpdateItem[] = [];
    try {
      // Check if the visibility for each person has been changed
      for (const person of people) {
        if (person.isHidden !== initialHiddenValues[person.id]) {
          changed.push({ id: person.id, isHidden: person.isHidden });

          // Update the initial hidden values
          initialHiddenValues[person.id] = person.isHidden;

          // Update the count of hidden/visible people
          countVisiblePeople += person.isHidden ? -1 : 1;
        }
      }

      if (changed.length > 0) {
        const { data: results } = await api.personApi.updatePeople({
          peopleUpdateDto: { people: changed },
        });
        const count = results.filter(({ success }) => success).length;
        if (results.length - count > 0) {
          notificationController.show({
            type: NotificationType.Error,
            message: `Unable to change the visibility for ${results.length - count} ${
              results.length - count <= 1 ? 'person' : 'people'
            }`,
          });
        }
        notificationController.show({
          type: NotificationType.Info,
          message: `Visibility changed for ${count} ${count <= 1 ? 'person' : 'people'}`,
        });
      }
    } catch (error) {
      handleError(
        error,
        `Unable to change the visibility for ${changed.length} ${changed.length <= 1 ? 'person' : 'people'}`,
      );
    }
    // Reset variables used on the "Show & hide faces" modal
    showLoadingSpinner = false;
    selectHidden = false;
    toggleVisibility = false;
  };

  const handleMergeSameFace = async (response: [PersonResponseDto, PersonResponseDto]) => {
    const [personToMerge, personToBeMergedIn] = response;
    showMergeModal = false;

    if (!edittingPerson) {
      return;
    }
    try {
      await api.personApi.mergePerson({
        id: personMerge2.id,
        mergePersonDto: { ids: [personToMerge.id] },
      });
      countVisiblePeople--;
      people = people.filter((person: PersonResponseDto) => person.id !== personToMerge.id);

      notificationController.show({
        message: 'Merge faces succesfully',
        type: NotificationType.Info,
      });
    } catch (error) {
      handleError(error, 'Unable to save name');
    }
    if (personToBeMergedIn.name !== personName && edittingPerson.id === personToBeMergedIn.id) {
      /*
       *
       * If the user merges one of the suggested people into the person he's editing it, it's merging the suggested person AND renames
       * the person he's editing
       *
       */
      try {
        await api.personApi.updatePerson({ id: personToBeMergedIn.id, personUpdateDto: { name: personName } });
        for (const person of people) {
          if (person.id === personToBeMergedIn.id) {
            person.name = personName;
            break;
          }
        }
        notificationController.show({
          message: 'Change name succesfully',
          type: NotificationType.Info,
        });

        // trigger reactivity
        people = people;
      } catch (error) {
        handleError(error, 'Unable to save name');
      }
    }
  };

  const handleChangeName = (detail: PersonResponseDto) => {
    showChangeNameModal = true;
    personName = detail.name;
    personMerge1 = detail;
    edittingPerson = detail;
  };

  const handleSetBirthDate = (detail: PersonResponseDto) => {
    showSetBirthDateModal = true;
    edittingPerson = detail;
  };

  const handleHideFace = async (detail: PersonResponseDto) => {
    try {
      const { data: updatedPerson } = await api.personApi.updatePerson({
        id: detail.id,
        personUpdateDto: { isHidden: true },
      });

      people = people.map((person: PersonResponseDto) => {
        if (person.id === updatedPerson.id) {
          return updatedPerson;
        }
        return person;
      });

      people.forEach((person: PersonResponseDto) => {
        initialHiddenValues[person.id] = person.isHidden;
      });

      countVisiblePeople--;

      showChangeNameModal = false;

      notificationController.show({
        message: 'Changed visibility succesfully',
        type: NotificationType.Info,
      });
    } catch (error) {
      handleError(error, 'Unable to hide person');
    }
  };

  const handleMergeFaces = (detail: PersonResponseDto) => {
    goto(`${AppRoute.PEOPLE}/${detail.id}?action=merge&previousRoute=${AppRoute.PEOPLE}`);
  };

  const submitNameChange = async () => {
    potentialMergePeople = [];
    showChangeNameModal = false;
    if (!edittingPerson || personName === edittingPerson.name) {
      return;
    }
    if (personName === '') {
      changeName();
      return;
    }
    const { data } = await api.searchApi.searchPerson({ name: personName, withHidden: true });

    // We check if another person has the same name as the name entered by the user

    const existingPerson = data.find(
      (person: PersonResponseDto) =>
        person.name.toLowerCase() === personName.toLowerCase() &&
        edittingPerson &&
        person.id !== edittingPerson.id &&
        person.name,
    );
    if (existingPerson) {
      personMerge2 = existingPerson;
      showMergeModal = true;
      potentialMergePeople = people
        .filter(
          (person: PersonResponseDto) =>
            personMerge2.name.toLowerCase() === person.name.toLowerCase() &&
            person.id !== personMerge2.id &&
            person.id !== personMerge1.id &&
            !person.isHidden,
        )
        .slice(0, 3);
      return;
    }
    changeName();
  };

  const submitBirthDateChange = async (value: string) => {
    showSetBirthDateModal = false;
    if (!edittingPerson || value === edittingPerson.birthDate) {
      return;
    }

    try {
      const { data: updatedPerson } = await api.personApi.updatePerson({
        id: edittingPerson.id,
        personUpdateDto: { birthDate: value.length > 0 ? value : null },
      });

      people = people.map((person: PersonResponseDto) => {
        if (person.id === updatedPerson.id) {
          return updatedPerson;
        }
        return person;
      });

      notificationController.show({
        message: 'Date of birth saved succesfully',
        type: NotificationType.Info,
      });
    } catch (error) {
      handleError(error, 'Unable to save name');
    }
  };

  const changeName = async () => {
    showMergeModal = false;
    showChangeNameModal = false;

    if (!edittingPerson) {
      return;
    }
    try {
      const { data: updatedPerson } = await api.personApi.updatePerson({
        id: edittingPerson.id,
        personUpdateDto: { name: personName },
      });

      people = people.map((person: PersonResponseDto) => {
        if (person.id === updatedPerson.id) {
          return updatedPerson;
        }
        return person;
      });

      notificationController.show({
        message: 'Change name succesfully',
        type: NotificationType.Info,
      });
    } catch (error) {
      handleError(error, 'Unable to save name');
    }
  };
</script>

{#if showMergeModal}
  <FullScreenModal on:clickOutside={() => (showMergeModal = false)}>
    <MergeSuggestionModal
      {personMerge1}
      {personMerge2}
      {potentialMergePeople}
      on:close={() => (showMergeModal = false)}
      on:reject={() => changeName()}
      on:confirm={(event) => handleMergeSameFace(event.detail)}
    />
  </FullScreenModal>
{/if}

<UserPageLayout user={data.user} title="People">
  <svelte:fragment slot="buttons">
    {#if countTotalPeople > 0}
      <IconButton on:click={() => (selectHidden = !selectHidden)}>
        <div class="flex flex-wrap place-items-center justify-center gap-x-1 text-sm">
          <Icon path={mdiEyeOutline} size="18" />
          <p class="ml-2">Show & hide faces</p>
        </div>
      </IconButton>
    {/if}
  </svelte:fragment>

  {#if countVisiblePeople > 0}
    <div class="pl-4">
      <div class="flex flex-row flex-wrap gap-1">
        {#each people as person (person.id)}
          {#if !person.isHidden}
            <PeopleCard
              {person}
              on:change-name={() => handleChangeName(person)}
              on:set-birth-date={() => handleSetBirthDate(person)}
              on:merge-faces={() => handleMergeFaces(person)}
              on:hide-face={() => handleHideFace(person)}
            />
          {/if}
        {/each}
      </div>
    </div>
  {:else}
    <div class="flex min-h-[calc(66vh_-_11rem)] w-full place-content-center items-center dark:text-white">
      <div class="flex flex-col content-center items-center text-center">
        <Icon path={mdiAccountOff} size="3.5em" />
        <p class="mt-5 text-3xl font-medium">No people</p>
      </div>
    </div>
  {/if}

  {#if showChangeNameModal}
    <FullScreenModal on:clickOutside={() => (showChangeNameModal = false)}>
      <div
        class="w-[500px] max-w-[95vw] rounded-3xl border bg-immich-bg p-4 py-8 shadow-sm dark:border-immich-dark-gray dark:bg-immich-dark-gray dark:text-immich-dark-fg"
      >
        <div
          class="flex flex-col place-content-center place-items-center gap-4 px-4 text-immich-primary dark:text-immich-dark-primary"
        >
          <h1 class="text-2xl font-medium text-immich-primary dark:text-immich-dark-primary">Change name</h1>
        </div>

        <form on:submit|preventDefault={submitNameChange} autocomplete="off">
          <div class="m-4 flex flex-col gap-2">
            <label class="immich-form-label" for="name">Name</label>
            <!-- svelte-ignore a11y-autofocus -->
            <input class="immich-form-input" id="name" name="name" type="text" bind:value={personName} autofocus />
          </div>

          <div class="mt-8 flex w-full gap-4 px-4">
            <Button
              color="gray"
              fullwidth
              on:click={() => {
                showChangeNameModal = false;
              }}>Cancel</Button
            >
            <Button type="submit" fullwidth>Ok</Button>
          </div>
        </form>
      </div>
    </FullScreenModal>
  {/if}

  {#if showSetBirthDateModal}
    <SetBirthDateModal
      birthDate={edittingPerson?.birthDate ?? ''}
      on:close={() => (showSetBirthDateModal = false)}
      on:updated={(event) => submitBirthDateChange(event.detail)}
    />
  {/if}
</UserPageLayout>
{#if selectHidden}
  <ShowHide
    on:doneClick={handleDoneClick}
    on:closeClick={handleCloseClick}
    on:reset-visibility={handleResetVisibility}
    on:toggle-visibility={handleToggleVisibility}
    bind:showLoadingSpinner
    bind:toggleVisibility
  >
    {#each people as person (person.id)}
      <button
        class="relative h-36 w-36 md:h-48 md:w-48"
        on:click={() => (person.isHidden = !person.isHidden)}
        on:mouseenter={() => (eyeColorMap[person.id] = 'black')}
        on:mouseleave={() => (eyeColorMap[person.id] = 'white')}
      >
        <ImageThumbnail
          bind:hidden={person.isHidden}
          shadow
          url={api.getPeopleThumbnailUrl(person.id)}
          altText={person.name}
          widthStyle="100%"
          bind:eyeColor={eyeColorMap[person.id]}
        />
        {#if person.name}
          <span class="absolute bottom-2 left-0 w-full select-text px-1 text-center font-medium text-white">
            {person.name}
          </span>
        {/if}
      </button>
    {/each}
  </ShowHide>
{/if}
