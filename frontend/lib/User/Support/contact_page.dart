import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8F6FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Contact', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Top blue wave
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: TopWaveClipper(),
              child: Container(
                height: 120,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          // Bottom blue wave
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipPath(
              clipper: BottomWaveClipper(),
              child: Container(
                height: 100,
                color: const Color(0xFF00B4D8),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20.0, vertical: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 80,
                          height: 80,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.account_balance_wallet,
                                  size: 64, color: Color(0xFF00B4D8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Center(
                      child: Text('Contact Us',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.black)),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'We would love to hear from you! Reach out to us through any of the following ways:',
                        style: TextStyle(fontSize: 15, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 6,
                      child: ListTile(
                        leading:
                            const Icon(Icons.email, color: Color(0xFF00B4D8)),
                        title: const Text('chetandudi791@gmail.com',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Email'),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 6,
                      child: ListTile(
                        leading: const Icon(Icons.facebook,
                            color: Color(0xFF00B4D8)),
                        title: const Text('Facebook',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('Lenden App'),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 6,
                      child: ListTile(
                        leading: const FaIcon(FontAwesomeIcons.whatsapp,
                            color: Color(0xFF00B4D8)),
                        title: const Text('WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('+91-XXXXXXXXXX'),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18)),
                      elevation: 6,
                      child: ListTile(
                        leading: const FaIcon(FontAwesomeIcons.instagram,
                            color: Color(0xFF00B4D8)),
                        title: const Text('Instagram',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: const Text('_Chetan_Dudi'),
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        label: const Text('Back to Home',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00B4D8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 32),
                          elevation: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Blue wave clippers (copied from main.dart)
class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.25, size.height, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.4, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class BottomWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.6,
        size.width * 0.5, size.height * 0.4);
    path.quadraticBezierTo(size.width * 0.75, 0, size.width, size.height * 0.4);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
