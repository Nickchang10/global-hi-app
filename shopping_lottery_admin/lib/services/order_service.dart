import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  final FirebaseFunctions functions;
  OrderService({FirebaseFunctions? functions})
    : functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items, // [{productId, qty}]
    required Map<String, dynamic> receiver, // {name, phone, address, note?}
    Map<String, dynamic>?
    shipping, // {method?, carrier?, trackingNumber?, trackingUrl?}
  }) async {
    final callable = functions.httpsCallable('createOrder');
    final res = await callable.call({
      'items': items,
      'receiver': receiver,
      'shipping': shipping ?? {},
    });
    return Map<String, dynamic>.from(res.data);
  }
}
