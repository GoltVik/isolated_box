import 'dart:async';

import 'package:example/counter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isolated_box/isolated_box.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final box = Completer<IsolatedBox<int>>();

  void _incrementCounter() async {
    /// Get the value from the box from Main isolate and increment it.
    try {
      final value = await (await box.future).getAt(0) ?? 0;
      await compute(callback, value);
    } catch (e) {
      await compute(callback, 0);
    }
  }

  static void callback(int value) async {
    /// Separate Isolate reuse the same boxName and update the value.
    final isolatedBox = await IsolatedBox.init<int>(boxName: 'counter');
    await isolatedBox.putAt(0, value + 1);
  }

  @override
  void initState() {
    IsolatedBox.init<int>(boxName: 'counter').then(box.complete);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: FutureBuilder<IsolatedBox<int>>(
          future: box.future,
          builder: (context, snapshot) {
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
  void dispose() async {
    (await box.future).dispose();
    super.dispose();
  }
}
