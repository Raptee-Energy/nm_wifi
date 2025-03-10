import 'package:flutter/material.dart';

class ConnectionStatusCard extends StatelessWidget {
  final String connectionStatus;
  final String? connectedNetworkName;
  final String? connectedNetworkSignal;
  final VoidCallback onDisconnect;

  const ConnectionStatusCard({
    super.key,
    required this.connectionStatus,
    this.connectedNetworkName,
    this.connectedNetworkSignal,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Status',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              connectionStatus,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (connectedNetworkSignal != null) ...[
              const SizedBox(height: 4),
              Text(
                'Signal: $connectedNetworkSignal',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (connectedNetworkName != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: onDisconnect,
                child: const Text('Disconnect'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
