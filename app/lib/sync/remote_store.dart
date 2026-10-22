/// The minimal file API sync needs. Implemented by Google Drive's
/// app-data folder, and by an in-memory fake in tests.
library;

class RemoteFile {
  const RemoteFile(this.id, this.name, this.checksum);
  final String id;
  final String name;

  /// Changes whenever the content changes (Drive's md5Checksum).
  final String checksum;
}

abstract class RemoteStore {
  /// Files whose name starts with [prefix].
  Future<List<RemoteFile>> list(String prefix);
  Future<List<int>> read(String id);

  /// Returns the new file's id.
  Future<String> create(String name, List<int> bytes);
  Future<void> update(String id, List<int> bytes);
}

/// A remote tied to a signed-in account, with the extras the UI needs.
abstract class AccountRemoteStore implements RemoteStore {
  /// The account's email address, if the provider reports it.
  Future<String?> accountEmail();

  /// Saves a user-visible backup file; returns a link to it if available.
  Future<String?> exportBackup(String name, List<int> bytes);
}
