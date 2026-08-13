/// Maps backend stop codes to driver-facing labels.
String? stopReasonLabel(String? reason) {
  switch (reason) {
    case null:
    case '':
      return null;
    case 'USER_STOPPED':
      return 'You stopped the session';
    case 'TARGET_SOC_REACHED':
    case 'TARGET_REACHED':
      return 'Target charge reached';
    case 'BALANCE_EXHAUSTED':
    case 'INSUFFICIENT_BALANCE':
      return 'Wallet balance used up';
    case 'REMOTE_STOPPED':
      return 'Stopped at the charge point';
    case 'EVSE_FAULT':
    case 'FAULTED':
    case 'FAULT':
      return 'Charger reported a fault';
    default:
      return 'Charger stopped';
  }
}
