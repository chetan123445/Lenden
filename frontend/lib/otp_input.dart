import 'package:flutter/material.dart';

class OtpInput extends StatefulWidget {
  final void Function(String) onChanged;
  final bool enabled;
  final bool autoFocus;
  const OtpInput({super.key, required this.onChanged, this.enabled = true, this.autoFocus = false});

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 6; i++) {
      _controllers[i].addListener(_onChanged);
    }
    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    String code = _controllers.map((c) => c.text).join();
    widget.onChanged(code);
    for (int i = 0; i < 6; i++) {
      if (_controllers[i].text.length > 1) {
        _controllers[i].text = _controllers[i].text.characters.last;
      }
      if (_controllers[i].text.isNotEmpty && i < 5) {
        _focusNodes[i + 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        return Container(
          width: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: TextField(
            controller: _controllers[i],
            focusNode: _focusNodes[i],
            enabled: widget.enabled,
            autofocus: widget.autoFocus && i == 0,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
            ),
            onTap: () => _controllers[i].selection = TextSelection(baseOffset: 0, extentOffset: _controllers[i].text.length),
          ),
        );
      }),
    );
  }
} 