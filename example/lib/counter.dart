import 'package:flutter/material.dart';
import 'package:isolated_box/isolated_box.dart';

class CounterView extends StatelessWidget {
  final IsolatedBox<int> box;

  const CounterView({super.key, required this.box});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: box.watch(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          /// Use the latest value from Stream.
          return Text(
            'Counter: ${snapshot.data!.value as int}',
            style: Theme.of(context).textTheme.headlineSmall,
          );
        }

        /// Fallback to the initial value.
        return FutureBuilder(
          future: box.get(0),
          builder: (_, snapshot) {
            return Text(
              'Counter: ${snapshot.data ?? -1}',
              style: Theme.of(context).textTheme.headlineSmall,
            );
          },
        );
      },
    );
  }
}
