import 'dart:async';

import 'package:flutter/material.dart';
import 'package:isolated_box/isolated_box.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _box = Completer<IsolatedBox<int>>();

  @override
  void initState() {
    super.initState();
    IsolatedBox.init<int>(boxName: 'counter').then(_box.complete);
  }

  int _counter = 0;

  void _incrementCounter() {
    _box.future.then((box) async {
      _counter++;
      await box.putAt(0, _counter);
      setState(() {});
    });
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
          future: _box.future,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return FutureBuilder<int?>(
                future: snapshot.data!.getAt(0),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(
                      'You have pushed the button this many times:',
                    );
                  } else {
                    return const CircularProgressIndicator();
                  }
                },
              );
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
}
