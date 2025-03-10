import 'package:flutter/material.dart';
import '../../Logic/DataModels/DataModels.dart';

class SavedConnectionTile extends StatelessWidget {
  final SavedConnection connection;
  final VoidCallback onConnect;
  final VoidCallback onRemove;

  const SavedConnectionTile({
    super.key,
    required this.connection,
    required this.onConnect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    bool isActive =
        connection.device.isNotEmpty && connection.device == 'wlan0';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(
          Icons.bookmark,
          color: isActive ? Colors.green : null,
        ),
        title: Text(
          connection.name,
          style: TextStyle(
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${connection.type}'),
            if (isActive) Text('Active on: ${connection.device}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: isActive ? null : onConnect,
              child: Text(isActive ? 'Connected' : 'Connect'),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
