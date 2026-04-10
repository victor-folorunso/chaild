/// ChaildStorage — local key-value and collection storage for Flutter apps.
///
/// Usage:
///   await ChaildStorage.initialize(namespace: 'my_app');
///   await ChaildStorage.set('theme', 'dark');
///   final theme = await ChaildStorage.get('theme');
library chaild_storage;

export 'src/chaild_storage_config.dart';
export 'src/chaild_collection.dart';
export 'src/chaild_query.dart';
