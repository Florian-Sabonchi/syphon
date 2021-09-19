import 'package:moor/moor.dart';
import 'package:syphon/storage/moor/database.dart';
import 'package:syphon/store/user/model.dart';

///
/// Users Model (Table)
///
/// Meant to store users in _cold storage_
/// using Moor and SQLite + SQLCipher
///
@UseRowClass(User)
class Users extends Table {
  TextColumn get userId => text().customConstraint('UNIQUE')();

  TextColumn get deviceId => text().nullable()();
  TextColumn get idserver => text().nullable()();
  TextColumn get homeserver => text().nullable()();
  TextColumn get homeserverName => text().nullable()();
  TextColumn get accessToken => text().nullable()();
  TextColumn get displayName => text().nullable()();
  TextColumn get avatarUri => text().nullable()();

  @override
  Set<Column> get primaryKey => {userId};
}

// example of loading queries separate from the database object
extension UserQueries on StorageDatabase {
  Future<void> insertUsersBatched(List<User> users) {
    return batch(
      (batch) => batch.insertAllOnConflictUpdate(
        this.users,
        users,
      ),
    );
  }
}
