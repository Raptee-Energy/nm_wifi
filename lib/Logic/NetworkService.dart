import 'dart:io';
import 'DataModels/DataModels.dart';

class NetworkService {
  Future<NetworkListResult> refreshAvailableNetworks() async {
    try {
      final result =
          await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
      if (result.exitCode == 0) {
        return NetworkListResult(
          success: true,
          networks: _parseWifiList(result.stdout as String),
        );
      } else {
        return NetworkListResult(
          success: false,
          errorMessage: 'Failed to retrieve available Wi-Fi networks.',
        );
      }
    } on ProcessException {
      return NetworkListResult(
        success: false,
        errorMessage: 'Error while trying to list Wi-Fi networks.',
      );
    } catch (e) {
      return NetworkListResult(
        success: false,
        errorMessage: 'An unexpected problem occurred while listing networks.',
      );
    }
  }

  List<WifiNetwork> _parseWifiList(String stdout) {
    List<WifiNetwork> networks = [];
    List<String> lines = stdout.split('\n');
    final fieldRegex = RegExp(r'(?<!\\):');

    for (String line in lines) {
      if (line.isEmpty) continue;

      bool isConnected = line.startsWith('*');
      String processedLine = line.replaceFirst(RegExp(r'^[* ]:'), '');

      List<String> fields = processedLine.split(fieldRegex);
      if (fields.length < 8) continue;

      String macAddress = fields[0];
      String rawSsid = fields[1];
      String ssid = rawSsid.replaceAll(r'\:', ':');
      String mode = fields[2];
      String channel = fields[3];
      String rate = fields[4];
      String signalStrength = fields[5];
      String bars = fields[6];
      String security = fields[7];

      int? channelNumber = int.tryParse(channel);
      if (channelNumber != null && channelNumber > 35) {
        networks.add(WifiNetwork(
          macAddress: macAddress,
          ssid: ssid,
          mode: mode,
          channel: channel,
          rate: rate,
          signalStrength: signalStrength,
          bars: bars,
          security: security,
          isConnected: isConnected,
          rawSsid: rawSsid,
        ));
      }
    }

    return networks;
  }

  Future<SavedConnectionsResult> refreshSavedConnections() async {
    try {
      final result = await Process.run('nmcli', ['-t', 'connection', 'show']);
      if (result.exitCode == 0) {
        return SavedConnectionsResult(
          success: true,
          connections: _parseConnectionShow(result.stdout as String),
        );
      } else {
        return SavedConnectionsResult(
          success: false,
          errorMessage: 'Failed to retrieve saved Wi-Fi connections.',
        );
      }
    } on ProcessException {
      return SavedConnectionsResult(
        success: false,
        errorMessage: 'Error while trying to list saved connections.',
      );
    } catch (e) {
      return SavedConnectionsResult(
        success: false,
        errorMessage:
            'An unexpected problem occurred while listing saved connections.',
      );
    }
  }

  List<SavedConnection> _parseConnectionShow(String stdout) {
    List<SavedConnection> connections = [];
    List<String> lines = stdout.split('\n');

    for (String line in lines) {
      if (line.isEmpty) continue;

      List<String> parts = line.split(':');
      if (parts.length >= 4) {
        connections.add(SavedConnection(
          name: parts[0],
          uuid: parts[1],
          type: parts[2],
          device: parts[3],
        ));
      }
    }
    return connections;
  }

  Future<ConnectionStatusResult> getConnectionStatus() async {
    try {
      final deviceResult =
          await Process.run('nmcli', ['-t', 'device', 'status']);
      if (deviceResult.exitCode == 0) {
        String? currentNetwork =
            _parseConnectedNetworkName(deviceResult.stdout as String);

        String? currentNetworkSignal;
        if (currentNetwork != null) {
          final wifiListResult =
              await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
          if (wifiListResult.exitCode == 0) {
            currentNetworkSignal = _getConnectedNetworkSignal(
                wifiListResult.stdout as String, currentNetwork);
          }
        }

        String status = currentNetwork != null
            ? 'Connected to $currentNetwork'
            : 'Not connected';
        return ConnectionStatusResult(
          success: true,
          statusMessage: status,
          networkName: currentNetwork,
          networkSignal: currentNetworkSignal,
        );
      } else {
        return ConnectionStatusResult(
          success: false,
          errorMessage: 'Failed to get the current connection status.',
        );
      }
    } on ProcessException {
      return ConnectionStatusResult(
        success: false,
        errorMessage: 'Error while checking connection status.',
      );
    } catch (e) {
      return ConnectionStatusResult(
        success: false,
        errorMessage:
            'An unexpected problem occurred while getting the connection status.',
      );
    }
  }

  String? _parseConnectedNetworkName(String statusOutput) {
    for (String line in statusOutput.split('\n')) {
      if (line.isEmpty) continue;

      List<String> parts = line.split(':');
      if (parts.length >= 4 && parts[0] == 'wlan0' && parts[2] == 'connected') {
        return parts[3];
      }
    }
    return null;
  }

  String? _getConnectedNetworkSignal(
      String wifiListOutput, String connectedNetwork) {
    List<WifiNetwork> networks = _parseWifiList(wifiListOutput);
    for (WifiNetwork network in networks) {
      if (network.isConnected && network.ssid == connectedNetwork) {
        return "${network.signalStrength} (${network.bars})";
      }
    }
    return null;
  }

  Future<bool> isNetworkAvailable(String ssid) async {
    try {
      final result =
          await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
      if (result.exitCode == 0) {
        List<WifiNetwork> networks = _parseWifiList(result.stdout as String);
        return networks.any((network) => network.ssid == ssid);
      } else {
        return false; // Assume not available if listing fails, handle error in connect
      }
    } on ProcessException catch (e) {
      print('Error checking network availability: ${e.message}');
      return false;
    } catch (e) {
      print('Error checking network availability: $e');
      return false;
    }
  }

  Future<ActionResponse> connectToNetwork(
      String rawSsid, String? password) async {
    try {
      List<String> command = ['device', 'wifi', 'connect', rawSsid];
      if (password != null && password.isNotEmpty) {
        command.addAll(['password', password]);
      }

      final result = await Process.run('nmcli', command);
      if (result.exitCode == 0) {
        return ActionResponse(success: true);
      } else {
        return ActionResponse(
          success: false,
          errorMessage:
              'Failed to connect to the Wi-Fi network. Incorrect Password.',
        );
      }
    } on ProcessException {
      return ActionResponse(
        success: false,
        errorMessage: 'Error while trying to connect to the Wi-Fi network.',
      );
    } catch (e) {
      return ActionResponse(
        success: false,
        errorMessage:
            'An unexpected problem occurred while connecting to the Wi-Fi network.',
      );
    }
  }

  Future<ActionResponse> connectToSavedConnection(String connectionName) async {
    try {
      final result =
          await Process.run('nmcli', ['connection', 'up', connectionName]);
      if (result.exitCode == 0) {
        return ActionResponse(success: true);
      } else {
        return ActionResponse(
          success: false,
          errorMessage: 'Failed to connect to the saved Wi-Fi connection.',
        );
      }
    } on ProcessException {
      return ActionResponse(
        success: false,
        errorMessage: 'Error while trying to connect to the saved connection.',
      );
    } catch (e) {
      return ActionResponse(
        success: false,
        errorMessage:
            'An unexpected problem occurred while connecting to the saved Wi-Fi connection.',
      );
    }
  }

  Future<ActionResponse> disconnectNetwork() async {
    try {
      final result =
          await Process.run('nmcli', ['device', 'disconnect', 'wlan0']);
      if (result.exitCode == 0) {
        return ActionResponse(success: true);
      } else {
        return ActionResponse(
          success: false,
          errorMessage: 'Failed to disconnect from the current Wi-Fi network.',
        );
      }
    } on ProcessException {
      return ActionResponse(
        success: false,
        errorMessage:
            'Error while trying to disconnect from the Wi-Fi network.',
      );
    } catch (e) {
      return ActionResponse(
        success: false,
        errorMessage:
            'An unexpected problem occurred while disconnecting from the Wi-Fi network.',
      );
    }
  }

  Future<ActionResponse> removeSavedConnection(String connectionName) async {
    try {
      final result =
          await Process.run('nmcli', ['connection', 'delete', connectionName]);
      if (result.exitCode == 0) {
        return ActionResponse(success: true);
      } else {
        return ActionResponse(
          success: false,
          errorMessage: 'Failed to remove the saved Wi-Fi connection.',
        );
      }
    } on ProcessException {
      return ActionResponse(
        success: false,
        errorMessage: 'Error while trying to remove the saved connection.',
      );
    } catch (e) {
      return ActionResponse(
        success: false,
        errorMessage:
            'An unexpected problem occurred while removing the saved Wi-Fi connection.',
      );
    }
  }
}
