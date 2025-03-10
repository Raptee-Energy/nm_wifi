import 'package:flutter/material.dart';
import '../../Logic/DataModels/DataModels.dart';

class WifiNetworkTile extends StatelessWidget {
  final WifiNetwork network;
  final VoidCallback onConnect;

  const WifiNetworkTile({
    super.key,
    required this.network,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(
          Icons.wifi,
          color: network.isConnected ? Colors.green : null,
        ),
        title: Text(
          network.ssid,
          style: TextStyle(
            fontWeight:
                network.isConnected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Signal: ${network.signalStrength} (${network.bars})'),
            if (network.security.isNotEmpty && network.security != '--')
              Text('Security: ${network.security}'),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: network.isConnected ? null : onConnect,
          child: Text(network.isConnected ? 'Connected' : 'Connect'),
        ),
      ),
    );
  }
}
