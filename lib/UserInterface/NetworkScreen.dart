

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:virtual_keyboard_multi_language/virtual_keyboard_multi_language.dart';

import '../Logic/DataModels/DataModels.dart';
import '../Logic/NetworkService.dart';
import 'Widgets/ConnectionStatusCard.dart';
import 'Widgets/SavedConnectionTile.dart';
import 'Widgets/WiFiNetworkTile.dart';
import 'Widgets/WiFiToggleButton.dart';

class NetworkScreen extends StatefulWidget {
  const NetworkScreen({super.key});

  @override
  State<NetworkScreen> createState() => _NetworkScreenState();
}

enum WifiIconStatus { loading, connected, disconnected, error }

class _NetworkScreenState extends State<NetworkScreen>
    with TickerProviderStateMixin {
  final NetworkService _networkService = NetworkService();
  List<WifiNetwork> _availableNetworks = [];
  List<SavedConnection> _savedConnections = [];
  String _connectionStatus = 'Loading status...';
  String? _connectedNetworkName;
  String? _connectedNetworkSignal;
  final TextEditingController _passwordController = TextEditingController();
  late TabController _tabController;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  WifiIconStatus _wifiIconStatus = WifiIconStatus.loading;
  String _wifiIconTooltip = 'Loading WiFi status...';

  String? _snackbarMessage;
  bool _snackbarIsError = false;
  bool _isSnackbarVisible = false;
  Timer? _snackbarTimer;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _tabController = TabController(length: 2, vsync: this);
    _startAutoRefresh();
    _startWifiIconRefresh();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_isRefreshing) {
        _refreshData();
      }
    });
  }

  void _startWifiIconRefresh() {
    Timer.periodic(const Duration(seconds: 3), (timer) {
      _refreshWifiIconStatus();
    });
  }

  Future<void> _refreshWifiIconStatus() async {
    try {
      final statusResult = await _networkService.getConnectionStatus();
      if (statusResult.networkName != null) {
        setState(() {
          _wifiIconStatus = WifiIconStatus.connected;
          _wifiIconTooltip =
              'Connected to ${statusResult.networkName}\nSignal: ${statusResult.networkSignal ?? 'N/A'}';
        });
      } else {
        setState(() {
          _wifiIconStatus = WifiIconStatus.disconnected;
          _wifiIconTooltip = 'Disconnected';
        });
      }
    } catch (e) {
      setState(() {
        _wifiIconStatus = WifiIconStatus.error;
        _wifiIconTooltip = 'Error fetching WiFi status';
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    _snackbarTimer?.cancel();
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
      final networksResult = await _networkService.refreshAvailableNetworks();
      if (networksResult.success) {
        setState(() {
          _availableNetworks = networksResult.networks ?? [];
        });
      } else {
        _showSnackbar(
            networksResult.errorMessage ?? 'Failed to list available networks.',
            isError: true);
      }
    } catch (e) {
      _showSnackbar('Unexpected error listing networks: $e', isError: true);
    }
  }

  Future<void> _refreshSavedConnections() async {
    try {
      final connectionsResult = await _networkService.refreshSavedConnections();
      if (connectionsResult.success) {
        setState(() {
          _savedConnections = connectionsResult.connections ?? [];
        });
      } else {
        _showSnackbar(
            connectionsResult.errorMessage ??
                'Failed to list saved connections.',
            isError: true);
      }
    } catch (e) {
      _showSnackbar('Unexpected error listing saved connections: $e',
          isError: true);
    }
  }

  Future<void> _getConnectionStatus() async {
    try {
      final statusResult = await _networkService.getConnectionStatus();
      if (statusResult.success) {
        setState(() {
          _connectionStatus = statusResult.statusMessage ?? 'Unknown status';
          _connectedNetworkName = statusResult.networkName;
          _connectedNetworkSignal = statusResult.networkSignal;
        });
      } else {
        setState(() {
          _connectionStatus = 'Error getting status';
        });
        _showSnackbar(
            statusResult.errorMessage ?? 'Error getting connection status.',
            isError: true);
      }
    } catch (e) {
      setState(() {
        _connectionStatus = 'Error getting status';
      });
      _showSnackbar('Unexpected error getting connection status: $e',
          isError: true);
    }
  }

  Future<void> _connectToNetwork(WifiNetwork network) async {
    if (!await _networkService.isNetworkAvailable(network.ssid)) {
      _showSnackbar('Network "${network.ssid}" is no longer available.',
          isError: true);
      await _refreshData();
      return;
    }

    String? password;
    if (network.security.isNotEmpty && network.security != '--') {
      password = await _showPasswordDialog(network.ssid);
      if (password == null) return;
    }

    setState(() => _connectionStatus = 'Connecting to ${network.ssid}...');

    try {
      final connectResult =
          await _networkService.connectToNetwork(network.rawSsid, password);
      if (connectResult.success) {
        _showSnackbar('Connected to ${network.ssid}', isError: false);
      } else {
        _showSnackbar(connectResult.errorMessage ?? 'Connection failed.',
            isError: true);
      }
      await _refreshData();
    } catch (e) {
      _showSnackbar('Error connecting to network: $e', isError: true);
      await _refreshData();
    }
  }

  Future<void> _connectToSavedConnection(SavedConnection connection) async {
    setState(() => _connectionStatus = 'Connecting to ${connection.name}...');
    try {
      final connectResult =
          await _networkService.connectToSavedConnection(connection.name);
      if (connectResult.success) {
        _showSnackbar('Connected to ${connection.name}', isError: false);
      } else {
        _showSnackbar(
            connectResult.errorMessage ??
                'Failed to connect to saved connection.',
            isError: true);
      }
      await _refreshData();
    } catch (e) {
      _showSnackbar('Error connecting to saved connection: $e', isError: true);
      await _refreshData();
    }
  }

  Future<void> _disconnectNetwork() async {
    setState(() => _connectionStatus = 'Disconnecting...');
    try {
      final disconnectResult = await _networkService.disconnectNetwork();
      if (disconnectResult.success) {
        _showSnackbar('Disconnected', isError: false);
      } else {
        _showSnackbar(disconnectResult.errorMessage ?? 'Failed to disconnect.',
            isError: true);
      }
      await _refreshData();
    } catch (e) {
      _showSnackbar('Error disconnecting: $e', isError: true);
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
      final removeResult =
          await _networkService.removeSavedConnection(connection.name);
      if (removeResult.success) {
        _showSnackbar('Removed ${connection.name}', isError: false);
      } else {
        _showSnackbar(
            removeResult.errorMessage ?? 'Failed to remove saved connection.',
            isError: true);
      }
      await _refreshData();
    } catch (e) {
      _showSnackbar('Error removing saved connection: $e', isError: true);
    }
  }

  void _showSnackbar(String message, {required bool isError}) {
    setState(() {
      _snackbarMessage = message;
      _snackbarIsError = isError;
      _isSnackbarVisible = true;
    });

    _snackbarTimer?.cancel();
    _snackbarTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _isSnackbarVisible = false;
      });
    });
  }

  IconData getWifiIconBasedOnStatus() {
    switch (_wifiIconStatus) {
      case WifiIconStatus.connected:
        return Icons.wifi;
      case WifiIconStatus.disconnected:
        return Icons.wifi_off;
      case WifiIconStatus.loading:
        return Icons.wifi_protected_setup;
      case WifiIconStatus.error:
      default:
        return Icons.wifi_off_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Manager'),
        actions: [
          const WifiToggleButton(),
          IconButton(
            icon: Tooltip(
              message: _wifiIconTooltip,
              child: Icon(getWifiIconBasedOnStatus()),
            ),
            onPressed: null,
          ),
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
        itemCount: _availableNetworks.length + 1 + (_isSnackbarVisible ? 1 : 0),
        itemBuilder: (context, index) {
          if (_isSnackbarVisible) {
            if (index == 0) {
              return _buildSnackbarCard();
            } else if (index == 1) {
              return ConnectionStatusCard(
                connectionStatus: _connectionStatus,
                connectedNetworkName: _connectedNetworkName,
                connectedNetworkSignal: _connectedNetworkSignal,
                onDisconnect: _disconnectNetwork,
              );
            } else {
              final network = _availableNetworks[index - 2];
              return WifiNetworkTile(
                network: network,
                onConnect: () => _connectToNetwork(network),
              );
            }
          } else {
            if (index == 0) {
              return ConnectionStatusCard(
                connectionStatus: _connectionStatus,
                connectedNetworkName: _connectedNetworkName,
                connectedNetworkSignal: _connectedNetworkSignal,
                onDisconnect: _disconnectNetwork,
              );
            } else {
              final network = _availableNetworks[index - 1];
              return WifiNetworkTile(
                network: network,
                onConnect: () => _connectToNetwork(network),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildSnackbarCard() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeInOutCubic,
      child: _isSnackbarVisible && _snackbarMessage != null
          ? Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                setState(() {
                  _isSnackbarVisible = false;
                });
                _snackbarTimer?.cancel();
              },
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(8),
                  color: _snackbarIsError ? Colors.red : Colors.green,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _snackbarMessage!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () {
                            setState(() {
                              _isSnackbarVisible = false;
                            });
                            _snackbarTimer?.cancel();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildSavedConnectionsList() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      child: ListView.builder(
        itemCount: _savedConnections.length,
        itemBuilder: (context, index) {
          final connection = _savedConnections[index];
          return SavedConnectionTile(
            connection: connection,
            onConnect: () => _connectToSavedConnection(connection),
            onRemove: () => _removeSavedConnection(connection),
          );
        },
      ),
    );
  }
}
