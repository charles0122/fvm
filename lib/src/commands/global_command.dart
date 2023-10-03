import 'package:fvm/src/models/cache_flutter_version_model.dart';
import 'package:fvm/src/models/flutter_version_model.dart';
import 'package:fvm/src/services/global_version_service.dart';
import 'package:fvm/src/services/logger_service.dart';
import 'package:fvm/src/services/project_service.dart';
import 'package:fvm/src/utils/console_utils.dart';
import 'package:fvm/src/utils/context.dart';
import 'package:fvm/src/utils/which.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:tint/tint.dart';

import '../services/cache_service.dart';
import '../workflows/ensure_cache.workflow.dart';
import 'base_command.dart';

/// Removes Flutter SDK
class GlobalCommand extends BaseCommand {
  @override
  final name = 'global';

  @override
  final description = 'Sets Flutter SDK Version as a global';

  /// Constructor
  GlobalCommand();

  @override
  String get invocation => 'fvm global {version}';

  @override
  Future<int> run() async {
    String? version;

    // Show chooser if not version is provided
    if (argResults!.rest.isEmpty) {
      final versions = await CacheService.fromContext.getAllVersions();
      version = await cacheVersionSelector(versions);
    }

    // Get first arg if it was not empty
    version ??= argResults!.rest[0];

    // Ensure version is installed
    final cacheVersion = await ensureCacheWorkflow(version);

    // Sets version as the global
    GlobalVersionService.fromContext.setGlobal(cacheVersion);

    final flutterInPath = which('flutter');

    // Get pinned version, for comparison on terminal
    final pinnedVersion = ProjectService.fromContext.findVersion();

    CacheFlutterVersion? pinnedCacheVersion;

    if (pinnedVersion != null) {
      //TODO: Should run validation on this
      final flutterPinnedVersion = FlutterVersion.parse(pinnedVersion);
      pinnedCacheVersion = CacheService.fromContext.getVersion(
        flutterPinnedVersion,
      );
    }

    final isDefaultInPath = flutterInPath == ctx.globalCacheBinPath;
    final isCachedVersionInPath = flutterInPath == cacheVersion.binPath;
    final isPinnedVersionInPath = flutterInPath == pinnedCacheVersion?.binPath;

    logger
      ..detail('')
      ..detail('Default in path: $isDefaultInPath')
      ..detail('Cached version in path: $isCachedVersionInPath')
      ..detail('Pinned version in path: $isPinnedVersionInPath')
      ..detail('')
      ..detail('flutterInPath: $flutterInPath')
      ..detail('ctx.globalCacheBinPath: ${ctx.globalCacheBinPath}')
      ..detail('cacheVersion.binPath: ${cacheVersion.binPath}')
      ..detail('pinnedCacheVersion?.binPath: ${pinnedCacheVersion?.binPath}')
      ..detail('');

    logger.info(
      'Flutter SDK: ${cyan.wrap(cacheVersion.printFriendlyName)} is now global',
    );

    if (!isDefaultInPath && !isCachedVersionInPath && !isPinnedVersionInPath) {
      logger
        ..info('')
        ..notice('However your configured "flutter" path is incorrect')
        ..info(
          'CURRENT: ${flutterInPath ?? 'No version is configured on path.'}'
              .brightRed(),
        )
        ..info('CHANGE TO: ${ctx.globalCacheBinPath}'.green())
        ..spacer;
    }

    logger.info(
      'Your IDE might override the PATH to the Flutter in their terminal to the one configured within the project.',
    );
    return ExitCode.success.code;
  }
}
