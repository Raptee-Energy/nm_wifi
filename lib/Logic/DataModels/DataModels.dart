class NetworkListResult {
  final bool success;
  final String? errorMessage;
  final List<WifiNetwork>? networks;

  NetworkListResult({
    required this.success,
    this.errorMessage,
    this.networks,
  });
}

class SavedConnectionsResult {
  final bool success;
  final String? errorMessage;
  final List<SavedConnection>? connections;

  SavedConnectionsResult({
    required this.success,
    this.errorMessage,
    this.connections,
  });
}

class ConnectionStatusResult {
  final bool success;
  final String? errorMessage;
  final String? statusMessage;
  final String? networkName;
  final String? networkSignal;

  ConnectionStatusResult({
    required this.success,
    this.errorMessage,
    this.statusMessage,
    this.networkName,
    this.networkSignal,
  });
}

class ActionResponse {
  final bool success;
  final String? errorMessage;

  ActionResponse({
    required this.success,
    this.errorMessage,
  });
}

class WifiRadioStatusResult {
  final bool success;
  final String? errorMessage;
  final String? status;

  WifiRadioStatusResult({
    required this.success,
    this.errorMessage,
    this.status,
  });
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
