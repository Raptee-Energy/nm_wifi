import 'package:flutter/material.dart';

import '../../Logic/NetworkService.dart';

class WifiToggleButton extends StatefulWidget {
  const WifiToggleButton({super.key});

  @override
  State<WifiToggleButton> createState() => _WifiToggleButtonState();
}

enum WifiToggleStatus {
  initial,
  turningOn,
  turningOff,
  enabled,
  disabled,
  error
}

class _WifiToggleButtonState extends State<WifiToggleButton> {
  WifiToggleStatus _wifiToggleStatus = WifiToggleStatus.initial;
  final NetworkService _networkService = NetworkService();
  bool _isWifiEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkWifiStatus();
  }

  Future<void> _checkWifiStatus() async {
    setState(() {
      _wifiToggleStatus = WifiToggleStatus.initial;
    });
    try {
      final statusResult = await _networkService.getWifiRadioStatus();
      if (statusResult.success) {
        setState(() {
          _isWifiEnabled = statusResult.status == 'enabled';
          _wifiToggleStatus = _isWifiEnabled
              ? WifiToggleStatus.enabled
              : WifiToggleStatus.disabled;
        });
      } else {
        setState(() {
          _wifiToggleStatus = WifiToggleStatus.error;
        });
      }
    } catch (e) {
      setState(() {
        _wifiToggleStatus = WifiToggleStatus.error;
      });
    }
  }

  Future<void> _toggleWifi(bool newValue) async {
    if (_wifiToggleStatus == WifiToggleStatus.turningOn ||
        _wifiToggleStatus == WifiToggleStatus.turningOff) {
      return;
    }

    if (newValue) {
      await _turnOnWifi();
    } else {
      await _turnOffWifi();
    }
  }

  Future<void> _turnOnWifi() async {
    setState(() {
      _wifiToggleStatus = WifiToggleStatus.turningOn;
    });
    try {
      final result = await _networkService.turnWifiOn();
      if (result.success) {
        setState(() {
          _isWifiEnabled = true;
          _wifiToggleStatus = WifiToggleStatus.enabled;
        });
      } else {
        setState(() {
          _wifiToggleStatus = WifiToggleStatus.error;
          _isWifiEnabled = false;
        });
      }
    } catch (e) {
      setState(() {
        _wifiToggleStatus = WifiToggleStatus.error;
        _isWifiEnabled = false;
      });
    }
  }

  Future<void> _turnOffWifi() async {
    setState(() {
      _wifiToggleStatus = WifiToggleStatus.turningOff;
    });
    try {
      final result = await _networkService.turnWifiOff();
      if (result.success) {
        setState(() {
          _isWifiEnabled = false;
          _wifiToggleStatus = WifiToggleStatus.disabled;
        });
      } else {
        setState(() {
          _wifiToggleStatus = WifiToggleStatus.error;
          _isWifiEnabled = true;
        });
      }
    } catch (e) {
      setState(() {
        _wifiToggleStatus = WifiToggleStatus.error;
        _isWifiEnabled = true;

      });
    }
  }

  bool _isLoading() {
    return _wifiToggleStatus == WifiToggleStatus.turningOn ||
        _wifiToggleStatus == WifiToggleStatus.turningOff ||
        _wifiToggleStatus == WifiToggleStatus.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Switch(
          value: _isWifiEnabled,
          onChanged: _isLoading() ? null : (newValue) => _toggleWifi(newValue),
        ),
        if (_isLoading())
          const SizedBox(
            width: 20,
            height: 20,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.grey),
          ),
      ],
    );
  }
}
