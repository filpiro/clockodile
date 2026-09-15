import 'package:catui/catui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/clients/cubit/clients_cubit.dart';
import 'client_dot.dart';

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
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onChanged = widget.onChanged;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) {
        final text = value.text.trim();
        if (text.length < 3) return const Iterable<String>.empty();
        return context
            .read<ClientsCubit>()
            .state
            .map((c) => c.client.name)
            .where((n) => n.toLowerCase().contains(text.toLowerCase()));
      },
      onSelected: (v) => onChanged?.call(v),
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          autofocus: widget.autofocus,
          decoration: const InputDecoration(labelText: 'Cliente'),
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final clientColors = {
          for (final c in context.read<ClientsCubit>().state)
            c.client.name: c.client.colorHex,
        };
        // Arrow keys/Enter are handled by RawAutocomplete itself; here we only
        // make the highlighted option visible and keep it scrolled into view.
        final highlighted = AutocompleteHighlightedOption.of(context);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            // Same corner as dialogs: the popup is another floating surface.
            borderRadius: BorderRadius.circular(AppTokens.radius),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 320),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final (i, name) in options.indexed)
                    Builder(
                      builder: (context) {
                        final selected = i == highlighted;
                        if (selected) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              Scrollable.ensureVisible(context, alignment: 0.5);
                            }
                          });
                        }
                        return ListTile(
                          dense: true,
                          selected: selected,
                          // Text color alone reads poorly; give the highlighted
                          // option the same background a hovered list row gets.
                          selectedTileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          leading: ClientDot(clientColors[name]),
                          title: Text(name),
                          onTap: () => onSelected(name),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
