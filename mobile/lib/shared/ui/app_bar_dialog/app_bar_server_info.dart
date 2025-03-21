import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart' hide Store;
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/shared/models/server_info/server_info.model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:immich_mobile/shared/providers/server_info.provider.dart';
import 'package:immich_mobile/utils/url_helper.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppBarServerInfo extends HookConsumerWidget {
  const AppBarServerInfo({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ServerInfo serverInfoState = ref.watch(serverInfoProvider);

    final appInfo = useState({});

    getPackageInfo() async {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();

      appInfo.value = {
        "version": packageInfo.version,
        "buildNumber": packageInfo.buildNumber,
      };
    }

    useEffect(
      () {
        getPackageInfo();
        return null;
      },
      [],
    );

    return Padding(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0, bottom: 10.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).scaffoldBackgroundColor
              : const Color.fromARGB(255, 225, 229, 240),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  serverInfoState.isVersionMismatch
                      ? serverInfoState.versionMismatchErrorMessage
                      : "profile_drawer_client_server_up_to_date".tr(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  color: Color.fromARGB(101, 201, 201, 201),
                  thickness: 1,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "server_info_box_app_version".tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.labelSmall?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Text(
                        "${appInfo.value["version"]} build.${appInfo.value["buildNumber"]}",
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.color
                              ?.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  color: Color.fromARGB(101, 201, 201, 201),
                  thickness: 1,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "server_info_box_server_version".tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.labelSmall?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Text(
                        serverInfoState.serverVersion.major > 0
                            ? "${serverInfoState.serverVersion.major}.${serverInfoState.serverVersion.minor}.${serverInfoState.serverVersion.patch}"
                            : "?",
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.color
                              ?.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Divider(
                  color: Color.fromARGB(101, 201, 201, 201),
                  thickness: 1,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Text(
                        "server_info_box_server_url".tr(),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).textTheme.labelSmall?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.only(right: 10.0),
                      child: Tooltip(
                        verticalOffset: 0,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).primaryColor.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        message: getServerUrl() ?? '--',
                        preferBelow: false,
                        triggerMode: TooltipTriggerMode.tap,
                        child: Text(
                          getServerUrl() ?? '--',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.color
                                ?.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                            overflow: TextOverflow.ellipsis,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
