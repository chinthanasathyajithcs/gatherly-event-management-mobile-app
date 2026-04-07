import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_paypal/flutter_paypal.dart';

class PayPalCheckoutService {
  static Future<Map<String, dynamic>?> showCheckout({
    required BuildContext context,
    required List<Map<String, dynamic>> transactions,
    required String note,
    bool sandboxMode = true,
    String returnUrl = 'return.example.com',
    String cancelUrl = 'cancel.example.com',
  }) {
    final clientId = dotenv.env['PAYPAL_CLIENT_ID']?.trim() ?? '';
    final secretKey = dotenv.env['PAYPAL_SECRET']?.trim() ?? '';
    final sandboxEnv = dotenv.env['PAYPAL_SANDBOX']?.trim().toLowerCase();
    final effectiveSandboxMode = sandboxEnv == null || sandboxEnv.isEmpty
        ? sandboxMode
        : (sandboxEnv == 'true' || sandboxEnv == '1' || sandboxEnv == 'yes');

    if (clientId.isEmpty || secretKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'PayPal keys are missing. Add PAYPAL_CLIENT_ID and PAYPAL_SECRET to .env.',
          ),
        ),
      );
      return Future<Map<String, dynamic>?>.value(null);
    }

    debugPrint(
      'PayPal checkout started (sandbox: $effectiveSandboxMode, returnURL: $returnUrl, cancelURL: $cancelUrl)',
    );

    final navigator = Navigator.of(context, rootNavigator: true);
    final normalizedReturnUrl = returnUrl.trim();
    final normalizedCancelUrl = cancelUrl.trim();

    final checkoutFuture = navigator.push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (BuildContext routeContext) => UsePaypal(
          sandboxMode: effectiveSandboxMode,
          clientId: clientId,
          secretKey: secretKey,
          returnURL: normalizedReturnUrl,
          cancelURL: normalizedCancelUrl,
          transactions: transactions,
          note: note,
          onSuccess: (Map params) {
            debugPrint('PayPal onSuccess: $params');
            if (navigator.canPop()) {
              navigator.pop(Map<String, dynamic>.from(params));
            }
          },
          onError: (error) {
            final message = error?.toString().trim();
            debugPrint('PayPal onError: $message');
            ScaffoldMessenger.of(routeContext).showSnackBar(
              SnackBar(
                content: Text(
                  (message == null || message.isEmpty)
                      ? 'Payment Error'
                      : 'Payment Error: $message',
                ),
              ),
            );
            if (navigator.canPop()) {
              navigator.pop(null);
            }
          },
          onCancel: (params) {
            debugPrint('PayPal onCancel: $params');
            ScaffoldMessenger.of(routeContext).showSnackBar(
              const SnackBar(content: Text('Payment Cancelled')),
            );
            if (navigator.canPop()) {
              navigator.pop(null);
            }
          },
        ),
      ),
    );

    return checkoutFuture.timeout(
      const Duration(minutes: 2),
      onTimeout: () async {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Payment is taking too long. Please try again.',
              ),
            ),
          );
          debugPrint(
              'PayPal checkout timeout reached. Closing checkout route.');
          await navigator.maybePop();
        }
        return null;
      },
    );
  }
}
