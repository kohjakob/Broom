import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/item.dart';
import '../models/category.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'broom.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        images TEXT NOT NULL DEFAULT '[]',
        thumbnail_image TEXT,
        ranking REAL NOT NULL DEFAULT 5.0,
        rating_count INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        emoji TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE item_categories (
        item_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        PRIMARY KEY (item_id, category_id),
        FOREIGN KEY (item_id) REFERENCES items(id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE
      )
    ''');
  }


  Future<void> insertItem(Item item) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('items', item.toMap());
      for (final categoryId in item.categories) {
        await txn.insert('item_categories', {
          'item_id': item.itemId,
          'category_id': categoryId,
        });
      }
    });
  }

  Future<void> updateItem(Item item) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.update(
        'items',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.itemId],
      );
      await txn.delete(
        'item_categories',
        where: 'item_id = ?',
        whereArgs: [item.itemId],
      );
      for (final categoryId in item.categories) {
        await txn.insert('item_categories', {
          'item_id': item.itemId,
          'category_id': categoryId,
        });
      }
    });
  }

  Future<void> deleteItem(String itemId) async {
    final db = await database;
    await db.delete('items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<Item?> getItem(String itemId) async {
    final db = await database;
    final maps = await db.query('items', where: 'id = ?', whereArgs: [itemId]);
    if (maps.isEmpty) return null;
    final categoryIds = await _getCategoryIdsForItem(db, itemId);
    return Item.fromMap(maps.first, categoryIds: categoryIds);
  }

  Future<List<Item>> getAllItems() async {
    final db = await database;
    final maps = await db.query('items', orderBy: 'created_at DESC');
    final allAssociations = await db.query('item_categories');

    final categoryMap = <String, List<String>>{};
    for (final row in allAssociations) {
      final itemId = row['item_id'] as String;
      final categoryId = row['category_id'] as String;
      categoryMap.putIfAbsent(itemId, () => []).add(categoryId);
    }

    return maps.map((map) {
      final itemId = map['id'] as String;
      return Item.fromMap(map, categoryIds: categoryMap[itemId] ?? []);
    }).toList();
  }

  Future<List<Item>> getItemsByCategories(List<String> categoryIds) async {
    if (categoryIds.isEmpty) return getAllItems();

    final db = await database;
    final placeholders = categoryIds.map((_) => '?').join(',');
    final itemIds = await db.rawQuery(
      'SELECT DISTINCT item_id FROM item_categories WHERE category_id IN ($placeholders)',
      categoryIds,
    );

    if (itemIds.isEmpty) return [];

    final ids = itemIds.map((r) => r['item_id'] as String).toList();
    final idPlaceholders = ids.map((_) => '?').join(',');
    final maps = await db.rawQuery(
      'SELECT * FROM items WHERE id IN ($idPlaceholders) ORDER BY created_at DESC',
      ids,
    );

    final allAssociations = await db.rawQuery(
      'SELECT * FROM item_categories WHERE item_id IN ($idPlaceholders)',
      ids,
    );

    final categoryMap = <String, List<String>>{};
    for (final row in allAssociations) {
      final itemId = row['item_id'] as String;
      final catId = row['category_id'] as String;
      categoryMap.putIfAbsent(itemId, () => []).add(catId);
    }

    return maps.map((map) {
      final itemId = map['id'] as String;
      return Item.fromMap(map, categoryIds: categoryMap[itemId] ?? []);
    }).toList();
  }

  Future<List<String>> _getCategoryIdsForItem(Database db, String itemId) async {
    final rows = await db.query(
      'item_categories',
      columns: ['category_id'],
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return rows.map((r) => r['category_id'] as String).toList();
  }

  Future<void> insertCategory(Category category) async {
    final db = await database;
    await db.insert('categories', category.toMap());
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.categoryId],
    );
  }

  Future<void> deleteCategory(String categoryId) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [categoryId]);
  }

  Future<List<Category>> getAllCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<List<String>> getCategoryIdsForItem(String itemId) async {
    final db = await database;
    return _getCategoryIdsForItem(db, itemId);
  }

  Future<List<String>> getItemIdsForCategory(String categoryId) async {
    final db = await database;
    final rows = await db.query(
      'item_categories',
      columns: ['item_id'],
      where: 'category_id = ?',
      whereArgs: [categoryId],
    );
    return rows.map((r) => r['item_id'] as String).toList();
  }

  Future<void> syncCategoryItems(String categoryId, List<String> itemIds) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('item_categories', where: 'category_id = ?', whereArgs: [categoryId]);
      for (final itemId in itemIds) {
        await txn.insert('item_categories', {
          'item_id': itemId,
          'category_id': categoryId,
        });
      }
    });
  }
}
