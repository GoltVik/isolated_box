import 'package:example/counter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isolated_box/isolated_box.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  IsolatedBox<int>? _box;

  void _incrementCounter() async {
    try {
      final value = await _box?.getAt(0) ?? 0;
      await compute(callback, value);
    } catch (e) {
      await compute(callback, 0);
    }
  }

  static void callback(int value) async {
    final isolatedBox = await IsolatedBox.init<int>(boxName: 'counter');
    await isolatedBox.putAt(0, value + 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<IsolatedBox<int>>(
          future: IsolatedBox.init<int>(boxName: 'counter'),
          initialData: _box,
          builder: (context, snapshot) {
            _box = snapshot.data;
            if (snapshot.hasData) {
              return CounterView(box: snapshot.data!);
            } else {
              return const CircularProgressIndicator();
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }

  @override
  void dispose() {
    _box?.dispose();
    super.dispose();
  }
}
