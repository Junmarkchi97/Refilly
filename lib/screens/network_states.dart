import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// Categorizes failures without claiming the network is offline just because
/// the server returned an error. Web transport errors often have no SocketException.
enum LoadFailure { offline, timeout, server }

LoadFailure classifyLoadFailure(Object error) {
  if (error is SocketException) return LoadFailure.offline;
  if (error is TimeoutException) return LoadFailure.timeout;
  final message = error.toString().toLowerCase();
  if (message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('clientexception: failed to fetch') ||
      message.contains('xmlhttprequest error') ||
      message.contains('connection refused')) {
    return LoadFailure.offline;
  }
  if (message.contains('timeout') || message.contains('timed out')) {
    return LoadFailure.timeout;
  }
  return LoadFailure.server;
}

/// Displayed after ~3 seconds without a completed request. This is deliberately
/// not a network status claim: it can be server latency or a slow connection.
class SlowLoadingHint extends StatefulWidget {
  const SlowLoadingHint({super.key, this.delay = const Duration(seconds: 3)});
  final Duration delay;
  @override
  State<SlowLoadingHint> createState() => _SlowLoadingHintState();
}

class _SlowLoadingHintState extends State<SlowLoadingHint> {
  Timer? _timer;
  bool _slow = false;
  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _slow = true);
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
      const SizedBox(height: 14),
      Text(_slow ? 'This is taking longer than usual…' : 'Loading…', textAlign: TextAlign.center),
      if (_slow) const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('Check your connection if it continues.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12)),
      ),
    ],
  );
}

class LoadFailureView extends StatelessWidget {
  const LoadFailureView({super.key, required this.error, required this.onRetry, this.compact = false});
  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final failure = classifyLoadFailure(error);
    final icon = switch (failure) {
      LoadFailure.offline => Icons.wifi_off_rounded,
      LoadFailure.timeout => Icons.hourglass_disabled_rounded,
      LoadFailure.server => Icons.cloud_off_rounded,
    };
    final title = switch (failure) {
      LoadFailure.offline => 'No internet connection',
      LoadFailure.timeout => 'Request timed out',
      LoadFailure.server => 'Could not load this right now',
    };
    final explanation = switch (failure) {
      LoadFailure.offline => 'Reconnect to Wi-Fi or mobile data, then retry.',
      LoadFailure.timeout => 'The service may be slow. Please try again.',
      LoadFailure.server => 'Your data is safe. Please try again in a moment.',
    };
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: compact ? 14 : 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: compact ? 32 : 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(explanation, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ]),
      ),
    );
  }
}
