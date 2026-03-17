import 'package:flutter/material.dart';

import '../models/message_data.dart';
import '../utils/data_converter.dart';

class FormatSelector extends StatelessWidget {
  final DataFormat value;
  final ValueChanged<DataFormat> onChanged;
  final String? label;
  final bool dense;

  const FormatSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectorFrame<DataFormat>(
      label: label,
      dense: dense,
      value: value,
      items: DataFormat.values.map((format) {
        return DropdownMenuItem<DataFormat>(
          value: format,
          child: Text(
            DataConverter.getFormatName(format),
            style: TextStyle(fontSize: dense ? 11 : 14),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }
}

class EncodingSelector extends StatelessWidget {
  final CharEncoding value;
  final ValueChanged<CharEncoding> onChanged;
  final String? label;
  final bool dense;

  const EncodingSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return _SelectorFrame<CharEncoding>(
      label: label,
      dense: dense,
      value: value,
      items: CharEncoding.values.map((encoding) {
        return DropdownMenuItem<CharEncoding>(
          value: encoding,
          child: Text(
            DataConverter.getEncodingName(encoding),
            style: TextStyle(fontSize: dense ? 11 : 14),
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null) {
          onChanged(newValue);
        }
      },
    );
  }
}

class DualFormatSelector extends StatelessWidget {
  final DataFormat sendFormat;
  final DataFormat receiveFormat;
  final ValueChanged<DataFormat> onSendFormatChanged;
  final ValueChanged<DataFormat> onReceiveFormatChanged;

  const DualFormatSelector({
    super.key,
    required this.sendFormat,
    required this.receiveFormat,
    required this.onSendFormatChanged,
    required this.onReceiveFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FormatSelector(
          label: '发',
          value: sendFormat,
          onChanged: onSendFormatChanged,
          dense: true,
        ),
        const SizedBox(width: 6),
        FormatSelector(
          label: '收',
          value: receiveFormat,
          onChanged: onReceiveFormatChanged,
          dense: true,
        ),
      ],
    );
  }
}

class FormatEncodingSelector extends StatelessWidget {
  final DataFormat format;
  final CharEncoding encoding;
  final ValueChanged<DataFormat> onFormatChanged;
  final ValueChanged<CharEncoding> onEncodingChanged;
  final String? formatLabel;
  final String? encodingLabel;

  const FormatEncodingSelector({
    super.key,
    required this.format,
    required this.encoding,
    required this.onFormatChanged,
    required this.onEncodingChanged,
    this.formatLabel = '格式',
    this.encodingLabel = '编码',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FormatSelector(
          label: formatLabel,
          value: format,
          onChanged: onFormatChanged,
          dense: true,
        ),
        const SizedBox(width: 6),
        EncodingSelector(
          label: encodingLabel,
          value: encoding,
          onChanged: onEncodingChanged,
          dense: true,
        ),
      ],
    );
  }
}

class _SelectorFrame<T> extends StatelessWidget {
  final T value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;
  final String? label;
  final bool dense;

  const _SelectorFrame({
    required this.value,
    required this.onChanged,
    required this.items,
    this.label,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 12,
        vertical: dense ? 0 : 4,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: dense ? 11 : null,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 6),
          ],
          DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              iconSize: dense ? 18 : 24,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
