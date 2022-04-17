import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_practice_app/controllers/auth_controller.dart';
import 'package:riverpod_practice_app/controllers/item_list_controller.dart';
import 'package:riverpod_practice_app/models/item_model.dart';
import 'package:riverpod_practice_app/repositories/custom_exception.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<CustomException?>(itemListExceptionProvider, (previous, next) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(previous!.message!),
        ),
      );
    });

    // 変更点
    final authControllerState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        leading: authControllerState != null
            ? IconButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
                icon: const Icon(Icons.logout),
              )
            : null,
      ),
      body: const ItemList(),
      // 変更点
      // body: ProviderListener(
      //   provider: itemListExceptionProvider,
      //   onChange: (
      //     BuildContext context,
      //     StateController<CustomException?> customException,
      //   ) {
      //     ScaffoldMessenger.of(context).showSnackBar(
      //       SnackBar(
      //         backgroundColor: Colors.red,
      //         content: Text(customException.state!.message!),
      //       ),
      //     );
      //   },
      //   child: const ItemList(),
      // ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AddItemDialog.show(context, Item.empty()),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AddItemDialog extends HookConsumerWidget {
  static void show(BuildContext context, Item item) {
    showDialog(
      context: context,
      builder: (context) => AddItemDialog(item: item),
    );
  }

  final Item item;

  const AddItemDialog({Key? key, required this.item}) : super(key: key);

  bool get isUpdating => item.id != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textController = useTextEditingController(text: item.name);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: 12.0),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  primary: isUpdating
                      ? Colors.orange
                      : Theme.of(context).primaryColor,
                ),
                onPressed: () {
                  isUpdating
                      ? ref
                          .read(itemListControllerProvider.notifier)
                          .updateItem(
                            updatedItem: item.copyWith(
                              name: textController.text.trim(),
                              obtained: item.obtained,
                            ),
                          )
                      : ref
                          .read(itemListControllerProvider.notifier)
                          .addItem(name: textController.text.trim());
                  Navigator.of(context).pop();
                },
                child: Text(isUpdating ? 'Update' : 'Add'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final currentItem = Provider<Item>((_) => throw UnimplementedError());

class ItemList extends HookConsumerWidget {
  const ItemList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 変更点
    final itemListState = ref.watch(itemListControllerProvider);
    final filteredItemList = ref.watch(filteredItemListProvider);
    return itemListState.when(
      data: (items) => items.isEmpty
          ? const Center(
              child: Text(
                'Tap + to add an item',
                style: TextStyle(fontSize: 20.0),
              ),
            )
          : ListView.builder(
              itemCount: filteredItemList.length,
              itemBuilder: (BuildContext context, int index) {
                final item = filteredItemList[index];
                return ProviderScope(
                  overrides: [currentItem.overrideWithValue(item)],
                  child: const ItemTile(),
                );
              },
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ItemListError(
        message:
            error is CustomException ? error.message! : 'Something went wrong!',
      ),
    );
  }
}

class ItemTile extends HookConsumerWidget {
  const ItemTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(currentItem);
    return Slidable(
      endActionPane: ActionPane(
        extentRatio: 0.25,
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (context) {
              ref
                  .read(itemListControllerProvider.notifier)
                  .deleteItem(itemId: item.id!);
            },
            autoClose: true,
            backgroundColor: const Color(0xFFFE4A49),
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: ListTile(
        key: ValueKey(item.id),
        title: Text(item.name),
        trailing: Checkbox(
          value: item.obtained,
          onChanged: (val) => ref
              .read(itemListControllerProvider.notifier)
              .updateItem(updatedItem: item.copyWith(obtained: !item.obtained)),
        ),
        onTap: () => AddItemDialog.show(context, item),
        onLongPress: () => ref
            .read(itemListControllerProvider.notifier)
            .deleteItem(itemId: item.id!),
      ),
    );
  }
}

class ItemListError extends HookConsumerWidget {
  final String message;

  const ItemListError({
    Key? key,
    required this.message,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, style: const TextStyle(fontSize: 20.0)),
          const SizedBox(height: 20.0),
          ElevatedButton(
            onPressed: () => ref
                .read(itemListControllerProvider.notifier)
                .retrieveItems(isRefreshing: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
