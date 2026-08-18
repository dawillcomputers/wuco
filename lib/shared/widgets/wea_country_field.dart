import 'package:flutter/material.dart';

import '../data/countries.dart';

/// Picks the country a registrant is in.
///
/// A selector rather than a text box, because this field decides money. The
/// currency somebody is quoted and charged in follows from their country, and
/// that rule needs an ISO code — which no amount of free text reliably gives:
/// "Nigeria", "nigeria", "NGA" and a typo are four different strings for one
/// place, and three of them price as "somewhere unknown".
///
/// A registration taken before this existed holds a typed name, so the stored
/// value is resolved back to a code where it can be, rather than being
/// discarded the moment somebody opens the form again.
class WEACountryField extends StatelessWidget {
  const WEACountryField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country',
    this.helperText,
    this.validator,
  });

  /// The stored value: an ISO code, or a name from before this list existed.
  final String value;
  final ValueChanged<String> onChanged;
  final String label;
  final String? helperText;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final resolved = countryCode(value);

    return DropdownButtonFormField<String>(
      initialValue: resolved,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: const Icon(Icons.public, size: 20),
      ),
      // Long list, so it scrolls rather than trying to fill the screen.
      menuMaxHeight: 420,
      items: [
        for (final country in weaCountries)
          DropdownMenuItem(value: country.code, child: Text(country.name)),
      ],
      onChanged: (code) {
        if (code != null) onChanged(code);
      },
      validator: validator,
    );
  }
}
