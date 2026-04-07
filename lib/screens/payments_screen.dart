import 'package:flutter/material.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Payments',
          style: TextStyle(
            color: Color(0xFF0D1B2E),
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0D1B2E)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1B2E), Color(0xFF1E3250)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D1B2E).withValues(alpha: 0.2),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Color(0xFFCB6D22),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PayPal Payment',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Secure payments via PayPal',
                              style: TextStyle(
                                color: Color(0xFFB0BEC5),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Color(0xFFCB6D22), size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Payments are processed securely through PayPal sandbox mode for testing.',
                            style: TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Test Payment Button
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                color: Color(0xFF8A6D5A),
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 14),
            _PaymentActionCard(
              icon: Icons.payment_rounded,
              title: 'Test Payment',
              subtitle: 'Make a test PayPal transaction (\$1.00)',
              onTap: () => _makeTestPayment(context),
            ),
          ],
        ),
      ),
    );
  }

  void _makeTestPayment(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext ctx) => UsePaypal(
          sandboxMode: true,
          clientId: dotenv.env['PAYPAL_CLIENT_ID'] ?? "",
          secretKey: dotenv.env['PAYPAL_SECRET'] ?? "",
          returnURL: "https://samplesite.com/return",
          cancelURL: "https://samplesite.com/cancel",
          transactions: const [
            {
              "amount": {
                "total": '1.00',
                "currency": "USD",
                "details": {
                  "subtotal": '1.00',
                  "shipping": '0',
                  "shipping_discount": 0,
                },
              },
              "description": "Test Payment from Gatherly",
              "item_list": {
                "items": [
                  {
                    "name": "Test Payment",
                    "quantity": 1,
                    "price": '1.00',
                    "currency": "USD",
                  },
                ],
              },
            },
          ],
          note: "Test payment from Gatherly app.",
          onSuccess: (Map params) async {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => _PaymentResultPage(
                  success: true,
                  data: params,
                ),
              ),
            );
          },
          onError: (error) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Payment Error')),
            );
          },
          onCancel: (params) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(content: Text('Payment Cancelled')),
            );
          },
        ),
      ),
    );
  }
}

class _PaymentActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PaymentActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFCB6D22).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: const Color(0xFFCB6D22), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF0D1B2E),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8A98A9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentResultPage extends StatelessWidget {
  final bool success;
  final Map data;

  const _PaymentResultPage({required this.success, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1EB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Payment Result',
          style: TextStyle(
            color: Color(0xFF0D1B2E),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0D1B2E)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: success
                      ? const Color(0xFF1A8A5A).withValues(alpha: 0.12)
                      : Colors.red.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: success ? const Color(0xFF1A8A5A) : Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                success ? 'Payment Successful!' : 'Payment Failed',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0D1B2E),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Transaction: ${data.toString().substring(0, data.toString().length.clamp(0, 120))}...',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8A98A9),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                    (route) => route.isFirst || route.settings.name == '/',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFCB6D22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
