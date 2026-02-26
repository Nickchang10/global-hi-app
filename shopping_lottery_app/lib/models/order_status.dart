enum OrderStatus {
  draft,
  pendingPayment,
  paymentProcessing,
  paid,
  failed,
  cancelled,
  refunded,
}

OrderStatus orderStatusFromString(String v) {
  switch (v) {
    case 'draft':
      return OrderStatus.draft;
    case 'pending_payment':
      return OrderStatus.pendingPayment;
    case 'payment_processing':
      return OrderStatus.paymentProcessing;
    case 'paid':
      return OrderStatus.paid;
    case 'failed':
      return OrderStatus.failed;
    case 'cancelled':
      return OrderStatus.cancelled;
    case 'refunded':
      return OrderStatus.refunded;
    default:
      return OrderStatus.pendingPayment;
  }
}

String orderStatusToString(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return 'draft';
    case OrderStatus.pendingPayment:
      return 'pending_payment';
    case OrderStatus.paymentProcessing:
      return 'payment_processing';
    case OrderStatus.paid:
      return 'paid';
    case OrderStatus.failed:
      return 'failed';
    case OrderStatus.cancelled:
      return 'cancelled';
    case OrderStatus.refunded:
      return 'refunded';
  }
}
