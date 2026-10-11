import 'dart:async';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import 'backup_store.dart';

/// Excepción lanzada cuando se requiere interacción del usuario para iniciar sesión
/// o autorizar el acceso a Google Drive, pero la operación se ejecuta en modo no interactivo
/// (por ejemplo en segundo plano mediante workmanager).
class DriveAuthRequiredException implements Exception {
  final String message;
  const DriveAuthRequiredException([
    this.message = 'Se requiere autenticación interactiva con Google Drive.',
  ]);

  @override
  String toString() => 'DriveAuthRequiredException: $message';
}

/// Implementación de [BackupStore] que sincroniza respaldos con Google Drive.
///
/// Utiliza el scope `https://www.googleapis.com/auth/drive.file` para acceder
/// únicamente a los archivos creados por la aplicación Pockt.
class DriveBackupStore implements BackupStore {
  /// Nombre predeterminado de la carpeta en Google Drive donde se alojan los backups.
  static const defaultFolderName = 'Pockt · Backups';

  final Future<drive.DriveApi> Function()? driveApiFactory;
  final String folderName;
  final bool interactive;

  final drive.DriveApi? _injectedDriveApi;
  String? _cachedFolderId;

  DriveBackupStore({
    drive.DriveApi? driveApi,
    this.driveApiFactory,
    this.folderName = defaultFolderName,
    this.interactive = true,
  }) : _injectedDriveApi = driveApi;

  /// Constructor para ejecuciones en segundo plano (Workmanager).
  /// En este modo nunca se muestran ventanas de login o autorización interactiva.
  DriveBackupStore.background({
    drive.DriveApi? driveApi,
    Future<drive.DriveApi> Function()? driveApiFactory,
    String folderName = defaultFolderName,
  }) : this(
          driveApi: driveApi,
          driveApiFactory: driveApiFactory,
          folderName: folderName,
          interactive: false,
        );

  /// Obtiene un cliente de [drive.DriveApi] autorizado.
  ///
  /// No almacena el cliente indefinidamente porque el token de acceso vence (~1 hora).
  /// En cada operación renueva o solicita autorización silenciosa. Si se requiere
  /// interacción del usuario pero [interactive] es falso, lanza [DriveAuthRequiredException].
  Future<drive.DriveApi> _getDriveApi() async {
    if (_injectedDriveApi != null) {
      return _injectedDriveApi;
    }

    if (driveApiFactory != null) {
      return await driveApiFactory!();
    }

    final googleSignIn = GoogleSignIn.instance;
    try {
      await googleSignIn.initialize();
    } catch (_) {
      // Ignorar si ya fue inicializado previamente.
    }

    GoogleSignInAccount? account;
    try {
      account = await googleSignIn.attemptLightweightAuthentication();
    } catch (_) {
      // Si falla la verificación silenciosa
    }

    if (account == null) {
      if (!interactive) {
        throw const DriveAuthRequiredException(
          'No hay sesión activa de Google y el modo interactivo está deshabilitado.',
        );
      }
      account = await googleSignIn.authenticate();
    }

    // Intentar autorización silenciosa para los scopes de Drive
    GoogleSignInClientAuthorization? clientAuth =
        await account.authorizationClient.authorizationForScopes([
      drive.DriveApi.driveFileScope,
    ]);

    if (clientAuth == null) {
      if (!interactive) {
        throw const DriveAuthRequiredException(
          'Se requiere autorización para Google Drive y el modo interactivo está deshabilitado.',
        );
      }
      clientAuth = await account.authorizationClient.authorizeScopes([
        drive.DriveApi.driveFileScope,
      ]);
    }

    final authClient = clientAuth.authClient(
      scopes: [drive.DriveApi.driveFileScope],
    );

    return drive.DriveApi(authClient);
  }

  /// Busca la carpeta designada para Pockt en Drive o la crea si no existe.
  Future<String> _getOrCreateFolderId(drive.DriveApi api) async {
    if (_cachedFolderId != null) {
      return _cachedFolderId!;
    }

    final escapedName = folderName.replaceAll("'", r"\'");
    final search = await api.files.list(
      q: "mimeType = 'application/vnd.google-apps.folder' and name = '$escapedName' and trashed = false",
      spaces: 'drive',
      $fields: 'files(id, name)',
    );

    final files = search.files;
    if (files != null && files.isNotEmpty && files.first.id != null) {
      _cachedFolderId = files.first.id!;
      return _cachedFolderId!;
    }

    final newFolder = drive.File()
      ..name = folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    final created = await api.files.create(
      newFolder,
      $fields: 'id',
    );

    if (created.id == null) {
      throw Exception('No se pudo crear la carpeta "$folderName" en Google Drive');
    }

    _cachedFolderId = created.id!;
    return _cachedFolderId!;
  }

  /// Limpia la carpeta en caché para forzar una nueva búsqueda en caso de recreación.
  void clearCache() {
    _cachedFolderId = null;
  }

  @override
  Future<void> upload(String name, List<int> bytes) async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateFolderId(api);

    final fileMetadata = drive.File()
      ..name = name
      ..parents = [folderId];

    final media = drive.Media(
      Stream.value(bytes),
      bytes.length,
      contentType: 'application/octet-stream',
    );

    await api.files.create(
      fileMetadata,
      uploadMedia: media,
      $fields: 'id',
    );
  }

  @override
  Future<List<RemoteBackup>> list() async {
    final api = await _getDriveApi();
    final folderId = await _getOrCreateFolderId(api);

    final result = await api.files.list(
      q: "'$folderId' in parents and trashed = false",
      orderBy: 'createdTime desc',
      $fields: 'files(id, name, createdTime, size)',
    );

    final files = result.files ?? [];
    return files
        .where((f) => f.id != null && f.name != null)
        .map((f) => RemoteBackup(
              id: f.id!,
              name: f.name!,
              createdAt: f.createdTime?.toLocal() ?? DateTime.now(),
              sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
            ))
        .toList();
  }

  @override
  Future<List<int>> download(String id) async {
    final api = await _getDriveApi();
    final media = await api.files.get(
      id,
      downloadOptions: drive.DownloadOptions.fullMedia,
    );

    if (media is! drive.Media) {
      throw Exception('La respuesta de Google Drive no contiene el contenido del archivo');
    }

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }
    return bytes;
  }

  @override
  Future<void> delete(String id) async {
    final api = await _getDriveApi();
    await api.files.delete(id);
  }
}
