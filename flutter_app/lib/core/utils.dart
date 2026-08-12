// BigInt/decimal-string helpers for Wei values.
// No `double` is used anywhere in this file or for any balance computation.

/// Converts a user-entered ETH string (e.g. "1.5") to Wei as a decimal string.
/// Handles up to 18 decimal places without floating-point loss.
String ethToWei(String ethAmount) {
  ethAmount = ethAmount.trim();
  if (ethAmount.isEmpty) return '0';

  final parts = ethAmount.split('.');
  final wholePart = parts[0].isEmpty ? '0' : parts[0];
  String fracPart = parts.length > 1 ? parts[1] : '';

  // Truncate to 18 decimals max
  if (fracPart.length > 18) {
    fracPart = fracPart.substring(0, 18);
  }
  // Pad to 18 decimals
  fracPart = fracPart.padRight(18, '0');

  final weiString = '$wholePart$fracPart';
  // Strip leading zeros but keep at least '0'
  final wei = BigInt.parse(weiString);
  return wei.toString();
}

/// Converts a Wei decimal string to a human-readable ETH string.
/// Returns up to [decimals] places (default 6), stripping trailing zeros.
String weiToEth(String weiString, {int decimals = 6}) {
  if (weiString.isEmpty) return '0';

  final wei = BigInt.parse(weiString);
  final divisor = BigInt.from(10).pow(18);
  final whole = wei ~/ divisor;
  final remainder = wei.remainder(divisor).abs();

  if (remainder == BigInt.zero) return whole.toString();

  final fracStr = remainder.toString().padLeft(18, '0');
  // Take requested decimal count
  final truncated = fracStr.substring(0, decimals);
  // Strip trailing zeros
  final cleaned = truncated.replaceAll(RegExp(r'0+$'), '');

  if (cleaned.isEmpty) return whole.toString();
  return '$whole.$cleaned';
}

/// Formats a full Ethereum address to a shortened display form.
/// "0x1234...abcd" — 6 prefix chars + 4 suffix chars.
String shortenAddress(String address) {
  if (address.length < 12) return address;
  return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
}

/// Validates an Ethereum address (basic hex check, 42 chars with 0x prefix).
bool isValidEthAddress(String address) {
  if (address.length != 42) return false;
  if (!address.startsWith('0x')) return false;
  return RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address);
}

/// Formats Wei string for display with ETH suffix.
String formatBalance(String weiString, {int decimals = 6}) {
  return '${weiToEth(weiString, decimals: decimals)} ETH';
}
