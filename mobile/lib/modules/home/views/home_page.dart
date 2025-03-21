import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/modules/album/providers/album.provider.dart';
import 'package:immich_mobile/modules/album/providers/album_detail.provider.dart';
import 'package:immich_mobile/modules/album/providers/shared_album.provider.dart';
import 'package:immich_mobile/modules/album/services/album.service.dart';
import 'package:immich_mobile/modules/asset_viewer/services/asset_stack.service.dart';
import 'package:immich_mobile/modules/backup/providers/manual_upload.provider.dart';
import 'package:immich_mobile/modules/home/models/selection_state.dart';
import 'package:immich_mobile/modules/home/providers/multiselect.provider.dart';
import 'package:immich_mobile/modules/home/ui/asset_grid/immich_asset_grid.dart';
import 'package:immich_mobile/modules/home/ui/control_bottom_app_bar.dart';
import 'package:immich_mobile/modules/memories/ui/memory_lane.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/shared/models/album.dart';
import 'package:immich_mobile/shared/models/asset.dart';
import 'package:immich_mobile/shared/providers/asset.provider.dart';
import 'package:immich_mobile/shared/providers/server_info.provider.dart';
import 'package:immich_mobile/shared/providers/user.provider.dart';
import 'package:immich_mobile/shared/providers/websocket.provider.dart';
import 'package:immich_mobile/shared/ui/immich_app_bar.dart';
import 'package:immich_mobile/shared/ui/immich_loading_indicator.dart';
import 'package:immich_mobile/shared/ui/immich_toast.dart';
import 'package:immich_mobile/utils/selection_handlers.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiselectEnabled = ref.watch(multiselectProvider.notifier);
    final selectionEnabledHook = useState(false);
    final selectionAssetState = useState(const SelectionAssetState());

    final selection = useState(<Asset>{});
    final albums = ref.watch(albumProvider).where((a) => a.isRemote).toList();
    final sharedAlbums = ref.watch(sharedAlbumProvider);
    final albumService = ref.watch(albumServiceProvider);
    final currentUser = ref.watch(currentUserProvider);
    final trashEnabled =
        ref.watch(serverInfoProvider.select((v) => v.serverFeatures.trash));

    final tipOneOpacity = useState(0.0);
    final refreshCount = useState(0);
    final processing = useState(false);

    useEffect(
      () {
        ref.read(websocketProvider.notifier).connect();
        Future(() => ref.read(assetProvider.notifier).getAllAsset());
        ref.read(albumProvider.notifier).getAllAlbums();
        ref.read(sharedAlbumProvider.notifier).getAllSharedAlbums();
        ref.read(serverInfoProvider.notifier).getServerInfo();

        selectionEnabledHook.addListener(() {
          multiselectEnabled.state = selectionEnabledHook.value;
        });

        return () {
          // This does not work in tests
          if (kReleaseMode) {
            selectionEnabledHook.dispose();
          }
        };
      },
      [],
    );

    Widget buildBody() {
      void selectionListener(
        bool multiselect,
        Set<Asset> selectedAssets,
      ) {
        selectionEnabledHook.value = multiselect;
        selection.value = selectedAssets;
        selectionAssetState.value =
            SelectionAssetState.fromSelection(selectedAssets);
      }

      List<Asset> remoteOnlySelection({String? localErrorMessage}) {
        final Set<Asset> assets = selection.value;
        final bool onlyRemote = assets.every((e) => e.isRemote);
        if (!onlyRemote) {
          if (localErrorMessage != null && localErrorMessage.isNotEmpty) {
            ImmichToast.show(
              context: context,
              msg: localErrorMessage,
              gravity: ToastGravity.BOTTOM,
            );
          }
          return assets.where((a) => a.isRemote).toList();
        }
        return assets.toList();
      }

      void onShareAssets(bool shareLocal) {
        processing.value = true;
        if (shareLocal) {
          handleShareAssets(ref, context, selection.value.toList());
        } else {
          final ids = remoteOnlySelection().map((e) => e.remoteId!);
          AutoRouter.of(context)
              .push(SharedLinkEditRoute(assetsList: ids.toList()));
        }
        processing.value = false;
        selectionEnabledHook.value = false;
      }

      void onFavoriteAssets() async {
        processing.value = true;
        try {
          final remoteAssets = remoteOnlySelection(
            localErrorMessage: 'home_page_favorite_err_local'.tr(),
          );
          if (remoteAssets.isNotEmpty) {
            await handleFavoriteAssets(ref, context, remoteAssets);
          }
        } finally {
          processing.value = false;
          selectionEnabledHook.value = false;
        }
      }

      void onArchiveAsset() async {
        processing.value = true;
        try {
          final remoteAssets = remoteOnlySelection(
            localErrorMessage: 'home_page_archive_err_local'.tr(),
          );
          await handleArchiveAssets(ref, context, remoteAssets);
        } finally {
          processing.value = false;
          selectionEnabledHook.value = false;
        }
      }

      void onDelete() async {
        processing.value = true;
        try {
          await ref
              .read(assetProvider.notifier)
              .deleteAssets(selection.value, force: !trashEnabled);

          final hasRemote = selection.value.any((a) => a.isRemote);
          final assetOrAssets = selection.value.length > 1 ? 'assets' : 'asset';
          final trashOrRemoved =
              !trashEnabled ? 'deleted permanently' : 'trashed';
          if (hasRemote) {
            ImmichToast.show(
              context: context,
              msg: '${selection.value.length} $assetOrAssets $trashOrRemoved',
              gravity: ToastGravity.BOTTOM,
            );
          }
          selectionEnabledHook.value = false;
        } finally {
          processing.value = false;
        }
      }

      void onUpload() {
        processing.value = true;
        selectionEnabledHook.value = false;
        try {
          ref.read(manualUploadProvider.notifier).uploadAssets(
                context,
                selection.value.where((a) => a.storage == AssetState.local),
              );
        } finally {
          processing.value = false;
        }
      }

      void onAddToAlbum(Album album) async {
        processing.value = true;
        try {
          final Iterable<Asset> assets = remoteOnlySelection(
            localErrorMessage: "home_page_add_to_album_err_local".tr(),
          );
          if (assets.isEmpty) {
            return;
          }
          final result = await albumService.addAdditionalAssetToAlbum(
            assets,
            album,
          );

          if (result != null) {
            if (result.alreadyInAlbum.isNotEmpty) {
              ImmichToast.show(
                context: context,
                msg: "home_page_add_to_album_conflicts".tr(
                  namedArgs: {
                    "album": album.name,
                    "added": result.successfullyAdded.toString(),
                    "failed": result.alreadyInAlbum.length.toString(),
                  },
                ),
              );
            } else {
              ImmichToast.show(
                context: context,
                msg: "home_page_add_to_album_success".tr(
                  namedArgs: {
                    "album": album.name,
                    "added": result.successfullyAdded.toString(),
                  },
                ),
                toastType: ToastType.success,
              );

              ref.watch(albumProvider.notifier).getAllAlbums();
              ref.invalidate(albumDetailProvider(album.id));
            }
          }
        } finally {
          processing.value = false;
          selectionEnabledHook.value = false;
        }
      }

      void onCreateNewAlbum() async {
        processing.value = true;
        try {
          final Iterable<Asset> assets = remoteOnlySelection(
            localErrorMessage: "home_page_add_to_album_err_local".tr(),
          );
          if (assets.isEmpty) {
            return;
          }
          final result =
              await albumService.createAlbumWithGeneratedName(assets);

          if (result != null) {
            ref.watch(albumProvider.notifier).getAllAlbums();
            ref.watch(sharedAlbumProvider.notifier).getAllSharedAlbums();
            selectionEnabledHook.value = false;

            AutoRouter.of(context).push(AlbumViewerRoute(albumId: result.id));
          }
        } finally {
          processing.value = false;
        }
      }

      void onStack() async {
        try {
          processing.value = true;
          if (!selectionEnabledHook.value || selection.value.length < 2) {
            return;
          }
          final parent = selection.value.elementAt(0);
          selection.value.remove(parent);
          await ref.read(assetStackServiceProvider).updateStack(
                parent,
                childrenToAdd: selection.value.toList(),
              );
        } finally {
          processing.value = false;
          selectionEnabledHook.value = false;
        }
      }

      Future<void> refreshAssets() async {
        final fullRefresh = refreshCount.value > 0;
        await ref.read(assetProvider.notifier).getAllAsset(clear: fullRefresh);
        if (fullRefresh) {
          // refresh was forced: user requested another refresh within 2 seconds
          refreshCount.value = 0;
        } else {
          refreshCount.value++;
          // set counter back to 0 if user does not request refresh again
          Timer(const Duration(seconds: 4), () {
            refreshCount.value = 0;
          });
        }
      }

      buildLoadingIndicator() {
        Timer(const Duration(seconds: 2), () {
          tipOneOpacity.value = 1;
        });

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const ImmichLoadingIndicator(),
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  'home_page_building_timeline',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: Theme.of(context).primaryColor,
                  ),
                ).tr(),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: tipOneOpacity.value,
                child: SizedBox(
                  width: 250,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: const Text(
                      'home_page_first_time_notice',
                      textAlign: TextAlign.justify,
                      style: TextStyle(
                        fontSize: 12,
                      ),
                    ).tr(),
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            ref.watch(assetsProvider(currentUser?.isarId)).when(
                  data: (data) => data.isEmpty
                      ? buildLoadingIndicator()
                      : ImmichAssetGrid(
                          renderList: data,
                          listener: selectionListener,
                          selectionActive: selectionEnabledHook.value,
                          onRefresh: refreshAssets,
                          topWidget: (currentUser != null &&
                                  currentUser.memoryEnabled != null &&
                                  currentUser.memoryEnabled!)
                              ? const MemoryLane()
                              : const SizedBox(),
                          showStack: true,
                        ),
                  error: (error, _) => Center(child: Text(error.toString())),
                  loading: buildLoadingIndicator,
                ),
            if (selectionEnabledHook.value)
              ControlBottomAppBar(
                onShare: onShareAssets,
                onFavorite: onFavoriteAssets,
                onArchive: onArchiveAsset,
                onDelete: onDelete,
                onAddToAlbum: onAddToAlbum,
                albums: albums,
                sharedAlbums: sharedAlbums,
                onCreateNewAlbum: onCreateNewAlbum,
                onUpload: onUpload,
                enabled: !processing.value,
                selectionAssetState: selectionAssetState.value,
                onStack: onStack,
              ),
            if (processing.value) const Center(child: ImmichLoadingIndicator()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: !selectionEnabledHook.value ? const ImmichAppBar() : null,
      body: buildBody(),
    );
  }
}
