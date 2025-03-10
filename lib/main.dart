import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

void main() {
  runApp(const NetworkManagerApp());
}

class NetworkManagerApp extends StatelessWidget {
  const NetworkManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Network Manager',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: const NetworkScreen(),
    );
  }
}

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

class _NetworkScreenState extends State<NetworkScreen>
    with TickerProviderStateMixin {
  List<WifiNetwork> availableNetworks = [];
  List<SavedConnection> savedConnections = [];
  String connectionStatus = 'Loading status...';
  String? connectedNetworkName;
  String? connectedNetworkSignal;
  final TextEditingController _passwordController = TextEditingController();
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _tabController = TabController(length: 2, vsync: this);
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isRefreshing) {
        _refreshData();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      await Future.wait([
        _refreshAvailableNetworks(),
        _refreshSavedConnections(),
        _getConnectionStatus(),
      ]);
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _refreshAvailableNetworks() async {
    try {
      final result =
          await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
      if (result.exitCode == 0) {
        List<WifiNetwork> networks = _parseWifiList(result.stdout as String);
        setState(() => availableNetworks = networks);
      } else {
        _showError('Failed to list networks: ${result.stderr}');
      }
    } catch (e) {
      _showError('Error listing networks: $e');
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

  Future<void> _refreshSavedConnections() async {
    try {
      final result = await Process.run('nmcli', ['-t', 'connection', 'show']);
      if (result.exitCode == 0) {
        List<SavedConnection> connections =
            _parseConnectionShow(result.stdout as String);
        setState(() => savedConnections = connections);
      } else {
        _showError('Failed to list saved connections: ${result.stderr}');
      }
    } catch (e) {
      _showError('Error listing saved connections: $e');
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

  Future<void> _getConnectionStatus() async {
    try {
      final deviceResult =
          await Process.run('nmcli', ['-t', 'device', 'status']);
      if (deviceResult.exitCode == 0) {
        String? currentNetwork =
            _parseConnectedNetworkName(deviceResult.stdout as String);

        if (currentNetwork != null) {
          final wifiResult =
              await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
          if (wifiResult.exitCode == 0) {
            String? currentNetworkSignal = _getConnectedNetworkSignal(
                wifiResult.stdout as String, currentNetwork);

            setState(() {
              connectedNetworkName = currentNetwork;
              connectedNetworkSignal = currentNetworkSignal;
              connectionStatus = 'Connected to $connectedNetworkName';
            });
          }
        } else {
          setState(() {
            connectedNetworkName = null;
            connectedNetworkSignal = null;
            connectionStatus = 'Not connected';
          });
        }
      } else {
        setState(() => connectionStatus = 'Failed to get status');
        _showError('Failed to get connection status: ${deviceResult.stderr}');
      }
    } catch (e) {
      setState(() => connectionStatus = 'Error getting status');
      _showError('Error getting connection status: $e');
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

  Future<bool> _isNetworkAvailable(String ssid) async {
    try {
      final result =
          await Process.run('nmcli', ['-t', 'device', 'wifi', 'list']);
      if (result.exitCode == 0) {
        List<WifiNetwork> networks = _parseWifiList(result.stdout as String);
        return networks.any((network) => network.ssid == ssid);
      }
    } catch (e) {
      print('Error checking network availability: $e');
    }
    return false;
  }

  Future<void> _connectToNetwork(WifiNetwork network) async {
    // First check if the network is still available
    if (!await _isNetworkAvailable(network.ssid)) {
      _showError('Network "${network.ssid}" is no longer available');
      await _refreshData();
      return;
    }

    String? password;
    if (network.security.isNotEmpty && network.security != '--') {
      password = await _showPasswordDialog(network.ssid);
      if (password == null) return;
    }

    setState(() => connectionStatus = 'Connecting to ${network.ssid}...');

    try {
      // Use rawSsid which preserves the exact format from nmcli
      List<String> command = ['device', 'wifi', 'connect', network.rawSsid];
      if (password != null && password.isNotEmpty) {
        command.addAll(['password', password]);
      }

      final result = await Process.run('nmcli', command);

      if (result.exitCode == 0) {
        _showSuccess('Connected to ${network.ssid}');
        await _refreshData();
      } else {
        _showError('Connection failed: ${result.stderr}');
        await _refreshData();
      }
    } catch (e) {
      _showError('Error connecting: $e');
      await _refreshData();
    }
  }

  Future<void> _connectToSavedConnection(SavedConnection connection) async {
    setState(() => connectionStatus = 'Connecting to ${connection.name}...');
    try {
      final result =
          await Process.run('nmcli', ['connection', 'up', connection.name]);
      if (result.exitCode == 0) {
        _showSuccess('Connected to ${connection.name}');
        await _refreshData();
      } else {
        _showError('Failed to connect: ${result.stderr}');
        await _refreshData();
      }
    } catch (e) {
      _showError('Error connecting: $e');
      await _refreshData();
    }
  }

  Future<void> _disconnectNetwork() async {
    setState(() => connectionStatus = 'Disconnecting...');
    try {
      final result =
          await Process.run('nmcli', ['device', 'disconnect', 'wlan0']);
      if (result.exitCode == 0) {
        _showSuccess('Disconnected');
        await _refreshData();
      } else {
        _showError('Failed to disconnect: ${result.stderr}');
        await _refreshData();
      }
    } catch (e) {
      _showError('Error disconnecting: $e');
      await _refreshData();
    }
  }

  Future<String?> _showPasswordDialog(String ssid) async {
    _passwordController.clear();
    bool localPasswordVisible = false;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Enter password for $ssid'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _passwordController,
                  obscureText: !localPasswordVisible,
                  decoration: InputDecoration(
                    suffixIcon: IconButton(
                      icon: Icon(localPasswordVisible
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setDialogState(
                          () => localPasswordVisible = !localPasswordVisible),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: VirtualKeyboard(
                    textController: _passwordController,
                    type: VirtualKeyboardType.Alphanumeric,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _passwordController.text),
                child: const Text('Connect'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _removeSavedConnection(SavedConnection connection) async {
    try {
      final result =
          await Process.run('nmcli', ['connection', 'delete', connection.name]);
      if (result.exitCode == 0) {
        _showSuccess('Removed ${connection.name}');
        await _refreshData();
      } else {
        _showError('Failed to remove: ${result.stderr}');
      }
    } catch (e) {
      _showError('Error removing: $e');
    }
  }

  void _showError(String message) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );

  void _showSuccess(String message) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Manager'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Available Networks'),
            Tab(text: 'Saved Connections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNetworksList(),
          _buildSavedConnectionsList(),
        ],
      ),
    );
  }

  Widget _buildNetworksList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: availableNetworks.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
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
                        onPressed: _disconnectNetwork,
                        child: const Text('Disconnect'),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }

          final network = availableNetworks[index - 1];
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
                onPressed: network.isConnected
                    ? null
                    : () => _connectToNetwork(network),
                child: Text(network.isConnected ? 'Connected' : 'Connect'),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSavedConnectionsList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: savedConnections.length,
        itemBuilder: (context, index) {
          final connection = savedConnections[index];
          bool isActive = connection.device.isNotEmpty;

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
                    onPressed: isActive
                        ? null
                        : () => _connectToSavedConnection(connection),
                    child: Text(isActive ? 'Connected' : 'Connect'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => _removeSavedConnection(connection),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class WifiNetwork {
  final String macAddress;
  final String ssid;
  final String mode;
  final String channel;
  final String rate;
  final String signalStrength;
  final String bars;
  final String security;
  final bool isConnected;
  final String rawSsid;

  WifiNetwork({
    required this.macAddress,
    required this.ssid,
    required this.mode,
    required this.channel,
    required this.rate,
    required this.signalStrength,
    required this.bars,
    required this.security,
    required this.isConnected,
    required this.rawSsid,
  });
}

class SavedConnection {
  final String name;
  final String uuid;
  final String type;
  final String device;

  SavedConnection({
    required this.name,
    required this.uuid,
    required this.type,
    required this.device,
  });
}
