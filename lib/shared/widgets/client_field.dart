import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../features/clients/cubit/clients_cubit.dart';

/// Client name input with autocomplete from 3 typed characters (spec 4.2).
/// Resolution to an existing/new client happens at save time, not here.
class ClientField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  const ClientField({
    super.key,
    required this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  @override
  State<ClientField> createState() => _ClientFieldState();
}

class _ClientFieldState extends State<ClientField> {
  List<String> _suggestions = const [];

  void _changed(String value) {
    final text = value.trim().toLowerCase();
    setState(() {
      _suggestions = text.length < 3
          ? const []
          : [
              for (final c in context.read<ClientsCubit>().state)
                if (c.client.name.toLowerCase().contains(text)) c.client.name,
            ];
    });
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return AutoComplete(
      suggestions: _suggestions,
      // A pick replaces the whole field, not just the word being typed.
      mode: AutoCompleteMode.replaceAll,
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        onChanged: _changed,
      ),
    );
  }
}
