# Storage

`ChaildStorage` gives you a dead-simple way to save and retrieve data in your
app. You call `set` and `get`. The SDK handles everything else.

All data is stored locally on the device. It is namespaced to your app so
it never collides with data from other apps using the Chaild SDK.

---

## Setup

Call `ChaildStorage.initialize()` once in `main()` right after `ChaildAuth.initialize()`:

```dart
await ChaildAuth.initialize(...);
await ChaildStorage.initialize(namespace: 'my_calculator_app');
```

Use a short, unique namespace. Lowercase letters, numbers, and underscores only.
Use the same namespace every time. If you change it, existing saved data will
not be found.

---

## Key-Value Storage

Use this for settings, flags, preferences, and any single piece of data.

```dart
// Save
await ChaildStorage.set('theme', 'dark');
await ChaildStorage.set('fontSize', 16);
await ChaildStorage.set('lastOpenedAt', DateTime.now().toIso8601String());

// Read
final theme = await ChaildStorage.get('theme');         // returns 'dark'
final fontSize = await ChaildStorage.get('fontSize');   // returns 16

// Check existence
final exists = await ChaildStorage.has('theme');        // true

// Delete one key
await ChaildStorage.delete('theme');

// Wipe all storage for your app
await ChaildStorage.clear();
```

`get` returns `null` if the key does not exist. Values can be any JSON-
compatible type: String, int, double, bool, List, Map.

---

## Secure Storage

Use this for sensitive values like tokens, PINs, or anything you do not want
visible if the device is backed up or the storage is inspected.

```dart
await ChaildStorage.setSecure('user_pin', '1234');
final pin = await ChaildStorage.getSecure('user_pin');

await ChaildStorage.deleteSecure('user_pin');
```

Secure storage uses the device keychain on iOS and EncryptedSharedPreferences
on Android. It is slower than regular storage. Only use it for sensitive data.

---

## Collections

Use collections when you need to store a list of items -- notes, history
entries, favourites, transactions, anything with multiple records.

```dart
final notes = ChaildStorage.collection('notes');

// Add an item (returns the generated id)
final id = await notes.add({
  'title': 'My first note',
  'body': 'Hello Chaild',
  'pinned': false,
  'createdAt': DateTime.now().toIso8601String(),
});

// Get all items
final all = await notes.getAll();

// Get one item by id
final note = await notes.getById(id);

// Update an item (merges, does not replace)
await notes.update(id, {'pinned': true});

// Delete an item
await notes.delete(id);

// Wipe the entire collection
await notes.clear();
```

Each item automatically gets an `_id` field. You do not need to add one.

---

## Querying Collections

Filter items without loading everything manually.

```dart
// Simple equality filter
final pinned = await notes.where('pinned', isEqualTo: true);

// Numeric comparison
final recent = await notes.where('score', isGreaterThan: 50);
final cheap = await notes.where('price', isLessThan: 100);

// Text search
final results = await notes.where('title', contains: 'flutter');
```

Chaining conditions:

```dart
// AND -- both conditions must be true
final pinnedAndNew = await notes
  .where('pinned', isEqualTo: true)
  .and('score', isGreaterThan: 10);

// OR -- either condition is enough
final pinnedOrFeatured = await notes
  .where('pinned', isEqualTo: true)
  .or('featured', isEqualTo: true);

// Grouped conditions
final complex = await notes
  .where('archived', isEqualTo: false)
  .andGroup((q) => q
    .where('pinned', isEqualTo: true)
    .or('score', isGreaterThan: 100)
  );
```

Queries always return `List<Map<String, dynamic>>`. An empty list means no
matches, not an error.

---

## Limits

There is no hard limit on how much you store but keep in mind this is device
storage. Large collections with many items will be slower to query because
filtering happens in memory. If you are storing thousands of records, consider
whether a different approach suits your app better.

