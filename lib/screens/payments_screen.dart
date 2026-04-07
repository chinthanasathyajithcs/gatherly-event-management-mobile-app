import 'package:flutter/material.dart';
import 'package:flutter_paypal/flutter_paypal.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class Env {
  static String get clientId => dotenv.env['PAYPAL_CLIENT_ID'] ?? "";
  static String get secret => dotenv.env['PAYPAL_SECRET'] ?? "";
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Paypal',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const MyHomePage(title: 'Payment'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (BuildContext context) => UsePaypal(
                  sandboxMode: true,
                  clientId: Env.clientId,
                  secretKey: Env.secret,
                  returnURL: "https://samplesite.com/return",
                  cancelURL: "https://samplesite.com/cancel",
                  transactions: const [
                    {
                      "amount": {
                        "total": '10.12',
                        "currency": "USD",
                        "details": {
                          "subtotal": '10.12',
                          "shipping": '0',
                          "shipping_discount": 0,
                        },
                      },
                      "description": "Payment for demo product",
                      "item_list": {
                        "items": [
                          {
                            "name": "Demo Product",
                            "quantity": 1,
                            "price": '10.12',
                            "currency": "USD",
                          },
                        ],
                      },
                    },
                  ],
                  note: "Contact us for any questions.",
                  onSuccess: (Map params) async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PaymentSuccessScreen(data: params),
                      ),
                    );
                  },
                  onError: (error) {
                    print("ERROR: $error");
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Payment Error")),
                    );
                  },
                  onCancel: (params) {
                    print('CANCELLED: $params');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Payment Cancelled")),
                    );
                  },
                ),
              ),
            );
          },
          child: const Text("Make Payment"),
        ),
      ),
    );
  }
}

class PaymentSuccessScreen extends StatelessWidget {
  final Map data;

  const PaymentSuccessScreen({Key? key, required this.data}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payment Success")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Payment Successful!",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text("Transaction:\n$data"),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back"),
            ),
          ],
        ),
      ),
    );
  }
}
