import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:motobill/repository/pos_repository.dart';

void main() {
  late Database db;
  late PosRepository posRepository;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Create in-memory database
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          // Create necessary tables
          await db.execute('''
            CREATE TABLE customers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              legal_name TEXT,
              phone TEXT,
              email TEXT,
              gst_number TEXT,
              address_line1 TEXT,
              address_line2 TEXT,
              city TEXT,
              state TEXT,
              pincode TEXT,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');

          await db.execute('''
            CREATE TABLE products (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              part_number TEXT,
              selling_price REAL NOT NULL,
              cost_price REAL NOT NULL,
              is_taxable INTEGER NOT NULL DEFAULT 1,
              hsn_code_id INTEGER,
              uqc_id INTEGER,
              sub_category_id INTEGER,
              manufacturer_id INTEGER,
              is_enabled INTEGER NOT NULL DEFAULT 1,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');

          await db.execute('''
            CREATE TABLE bills (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_number TEXT NOT NULL,
              customer_id INTEGER NOT NULL,
              subtotal REAL NOT NULL,
              tax_amount REAL NOT NULL,
              total_amount REAL NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');

          await db.execute('''
            CREATE TABLE bill_items (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              bill_id INTEGER NOT NULL,
              product_id INTEGER NOT NULL,
              product_name TEXT NOT NULL,
              part_number TEXT,
              hsn_code TEXT,
              uqc_code TEXT,
              cost_price REAL NOT NULL,
              selling_price REAL NOT NULL,
              quantity INTEGER NOT NULL,
              subtotal REAL NOT NULL,
              cgst_rate REAL NOT NULL DEFAULT 0,
              sgst_rate REAL NOT NULL DEFAULT 0,
              igst_rate REAL NOT NULL DEFAULT 0,
              utgst_rate REAL NOT NULL DEFAULT 0,
              cgst_amount REAL NOT NULL DEFAULT 0,
              sgst_amount REAL NOT NULL DEFAULT 0,
              igst_amount REAL NOT NULL DEFAULT 0,
              utgst_amount REAL NOT NULL DEFAULT 0,
              tax_amount REAL NOT NULL,
              total_amount REAL NOT NULL,
              is_deleted INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL DEFAULT (datetime('now')),
              updated_at TEXT NOT NULL DEFAULT (datetime('now'))
            )
          ''');
        },
      ),
    );

    posRepository = PosRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Last Custom Price Feature', () {
    test('should return null when no previous sale exists', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Get last custom price (should be null)
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNull);
    });

    test('should return last custom price when previous sale exists', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create a bill with custom price
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customerId, 90.0, 16.2, 106.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, productId, 'Test Product', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Get last custom price
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNotNull);
      expect(lastPrice, equals(106.2)); // Total amount / quantity
    });

    test('should return most recent price when multiple sales exist', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create first bill (older)
      final billId1 = await db.rawInsert(
        '''
        INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now', '-2 days'))
        ''',
        ['BILL001', customerId, 90.0, 16.2, 106.2],
      );
      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId1, productId, 'Test Product', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Create second bill (newer with different price)
      final billId2 = await db.rawInsert(
        '''
        INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount, created_at)
        VALUES (?, ?, ?, ?, ?, datetime('now', '-1 day'))
        ''',
        ['BILL002', customerId, 95.0, 17.1, 112.1],
      );
      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId2, productId, 'Test Product', 50.0, 95.0, 1, 95.0, 17.1, 112.1],
      );

      // Get last custom price (should be from most recent bill)
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNotNull);
      expect(lastPrice, equals(112.1)); // Most recent price
    });

    test(
      'should calculate correct per-unit price for multiple quantities',
      () async {
        // Create customer and product
        final customerId = await db.rawInsert(
          'INSERT INTO customers (name) VALUES (?)',
          ['Test Customer'],
        );
        final productId = await db.rawInsert(
          'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
          ['Test Product', 100.0, 50.0],
        );

        // Create bill with multiple quantities
        final billId = await db.rawInsert(
          'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
          ['BILL001', customerId, 450.0, 81.0, 531.0],
        );

        await db.rawInsert(
          '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
          [
            billId,
            productId,
            'Test Product',
            50.0,
            90.0,
            5,
            450.0,
            81.0,
            531.0,
          ],
        );

        // Get last custom price (should be per unit)
        final lastPrice = await posRepository.getLastCustomPrice(
          customerId,
          productId,
        );

        expect(lastPrice, isNotNull);
        expect(lastPrice, equals(106.2)); // 531.0 / 5
      },
    );

    test('should ignore deleted bills', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create a deleted bill
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount, is_deleted) VALUES (?, ?, ?, ?, ?, ?)',
        ['BILL001', customerId, 90.0, 16.2, 106.2, 1],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, productId, 'Test Product', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Get last custom price (should be null since bill is deleted)
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNull);
    });

    test('should return prices for multiple products', () async {
      // Create customer
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );

      // Create products
      final product1Id = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Product 1', 100.0, 50.0],
      );
      final product2Id = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Product 2', 200.0, 100.0],
      );

      // Create bill with both products
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customerId, 290.0, 52.2, 342.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, product1Id, 'Product 1', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, product2Id, 'Product 2', 100.0, 200.0, 1, 200.0, 36.0, 236.0],
      );

      // Get last custom prices for both products
      final lastPrices = await posRepository.getLastCustomPrices(customerId, [
        product1Id,
        product2Id,
      ]);

      expect(lastPrices.length, equals(2));
      expect(lastPrices[product1Id], equals(106.2));
      expect(lastPrices[product2Id], equals(236.0));
    });

    test('should return only prices for products that were sold before', () async {
      // Create customer
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );

      // Create products
      final product1Id = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Product 1', 100.0, 50.0],
      );
      final product2Id = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Product 2', 200.0, 100.0],
      );

      // Create bill with only product 1
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customerId, 90.0, 16.2, 106.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, product1Id, 'Product 1', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Get last custom prices for both products
      final lastPrices = await posRepository.getLastCustomPrices(customerId, [
        product1Id,
        product2Id,
      ]);

      expect(lastPrices.length, equals(1));
      expect(lastPrices[product1Id], equals(106.2));
      expect(lastPrices[product2Id], isNull);
    });

    test('should return empty map when product list is empty', () async {
      // Create customer
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );

      // Get last custom prices for empty list
      final lastPrices = await posRepository.getLastCustomPrices(
        customerId,
        [],
      );

      expect(lastPrices, isEmpty);
    });

    test('should return null for zero quantity items', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create bill with zero quantity (edge case)
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customerId, 0.0, 0.0, 0.0],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, productId, 'Test Product', 50.0, 90.0, 0, 0.0, 0.0, 0.0],
      );

      // Get last custom price (should be null due to zero quantity)
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNull);
    });

    test('should not return prices for different customer', () async {
      // Create two customers
      final customer1Id = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Customer 1'],
      );
      final customer2Id = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Customer 2'],
      );

      // Create product
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create bill for customer 1
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customer1Id, 90.0, 16.2, 106.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, productId, 'Test Product', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Get last custom price for customer 2 (should be null)
      final lastPrice = await posRepository.getLastCustomPrice(
        customer2Id,
        productId,
      );

      expect(lastPrice, isNull);
    });

    test('should handle empty cart scenario correctly', () async {
      // Create customer and product
      final customerId = await db.rawInsert(
        'INSERT INTO customers (name) VALUES (?)',
        ['Test Customer'],
      );
      final productId = await db.rawInsert(
        'INSERT INTO products (name, selling_price, cost_price) VALUES (?, ?, ?)',
        ['Test Product', 100.0, 50.0],
      );

      // Create bill with custom price
      final billId = await db.rawInsert(
        'INSERT INTO bills (bill_number, customer_id, subtotal, tax_amount, total_amount) VALUES (?, ?, ?, ?, ?)',
        ['BILL001', customerId, 90.0, 16.2, 106.2],
      );

      await db.rawInsert(
        '''
        INSERT INTO bill_items (
          bill_id, product_id, product_name, cost_price, selling_price,
          quantity, subtotal, tax_amount, total_amount
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [billId, productId, 'Test Product', 50.0, 90.0, 1, 90.0, 16.2, 106.2],
      );

      // Get last custom price (should exist)
      final lastPrice = await posRepository.getLastCustomPrice(
        customerId,
        productId,
      );

      expect(lastPrice, isNotNull);
      expect(lastPrice, equals(106.2));

      // Verify that clearing cart would require clearing lastCustomPrices
      // This test validates the data layer is working correctly
      // The actual clearCart behavior is tested at ViewModel level
    });
  });
}
