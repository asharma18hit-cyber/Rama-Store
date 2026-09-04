import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  final List<Map<String, String>> _faqs = [
    {
      'question': 'How fast is Rama Store hyper-local delivery?',
      'answer': 'Orders within a 5km radius are fulfilled and delivered to your doorstep within 30 minutes. Express shipping is complimentary for orders above ₹500.'
    },
    {
      'question': 'How does the 10% Loyalty Cash-Back program work?',
      'answer': 'Every confirmed purchase credits 10% of the total item value into your Rama Store Loyalty Wallet upon successful order delivery. Wallet credits can be redeemed on any future checkout.'
    },
    {
      'question': 'What payment methods are supported?',
      'answer': 'We support instant UPI (Google Pay, PhonePe, Paytm, BHIM), major Credit & Debit Cards (Visa, Mastercard, RuPay), and Cash on Delivery (COD).'
    },
    {
      'question': 'What is the return & cancellation policy?',
      'answer': 'Unopened items can be cancelled or returned within 7 days of delivery. For COD orders, inventory is immediately released back to store stock.'
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFaqs = _faqs.where((faq) {
      if (_searchQuery.isEmpty) return true;
      return faq['question']!.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer']!.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3525CD)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'HELP CENTER & SUPPORT',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF3525CD)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Input
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(color: Color(0xFF0B1C30)),
              decoration: InputDecoration(
                hintText: 'Search help topics, returns, payment...',
                hintStyle: const TextStyle(color: Color(0xFF777587), fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC7C4D8), width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFC7C4D8), width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3525CD), width: 1.5),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF777587)),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'FREQUENTLY ASKED QUESTIONS',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Color(0xFF0B1C30)),
            ),
            const SizedBox(height: 12),

            ...filteredFaqs.map((faq) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    title: Text(
                      faq['question']!,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0B1C30)),
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                        child: Text(
                          faq['answer']!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF464555), height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class LegalScreen extends StatelessWidget {
  final String title;
  final String content;

  const LegalScreen({super.key, required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF3525CD)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title.toUpperCase(),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.8, color: Color(0xFF3525CD)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFC7C4D8), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            content,
            style: const TextStyle(fontSize: 13, color: Color(0xFF464555), height: 1.6),
          ),
        ),
      ),
    );
  }
}
