import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_config.dart';
import '../game/ui/theme.dart';

Future<void> showPolicy(BuildContext context) async {
  final text = await rootBundle.loadString('assets/privacy_tr.txt');
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Gizlilik ve veri kullanımı'),
      content: SingleChildScrollView(child: Text(text)),
      actions: [
        TextButton(
          onPressed: () async {
            var launched = false;
            try {
              launched = await launchUrl(
                Uri.parse(AppConfig.privacyUrl),
                mode: LaunchMode.externalApplication,
              );
            } catch (error) {
              debugPrint('Privacy URL could not be opened: $error');
            }
            if (!launched && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bağlantı açılamadı.')),
              );
            }
          },
          child: const Text('Web politikası'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}

class GDPRScreen extends StatefulWidget {
  const GDPRScreen({super.key, required this.onAccepted});
  final Future<void> Function() onAccepted;
  @override
  State<GDPRScreen> createState() => _GDPRScreenState();
}

class _GDPRScreenState extends State<GDPRScreen> {
  bool _accepted = false;
  bool _busy = false;
  String? _error;
  Future<void> _start() async {
    if (!_accepted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onAccepted();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Onay kaydedilemedi. Lütfen tekrar deneyin.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Eyebrow('ONE-TAP ARCADE'),
                const SizedBox(height: 24),
                Text(
                  'ORBIT\nPIXEL JUMP',
                  textAlign: TextAlign.center,
                  style: OrbitTheme.pixel(24),
                ),
                const SizedBox(height: 40),
                OrbitPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.shield_outlined,
                        color: OrbitTheme.mint,
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Kontrol sende.',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: OrbitTheme.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Skorun, ses tercihin ve okuduğun gizlilik politikası sürümü yalnızca cihazında saklanır.',
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Oyun reklam içerir. Reklamlar kişiselleştirilmez; tüm oyuncular için genel izleyici filtresi ve çocuk koruması uygulanır.',
                      ),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: _busy ? null : () => showPolicy(context),
                        icon: const Icon(Icons.article_outlined),
                        label: const Text('Gizlilik metnini oku'),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: _accepted,
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                _accepted = value ?? false;
                              }),
                        title: const Text(
                          'Gizlilik politikasını okudum',
                          style: TextStyle(fontSize: 14),
                        ),
                        subtitle: const Text(
                          'Bu bildirim reklam izni veya ebeveyn onayı değildir.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: OrbitTheme.coral),
                          ),
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _accepted && !_busy ? _start : null,
                        child: Text(_busy ? 'Hazırlanıyor…' : 'Oyuna Başla'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'contact@example.com',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
