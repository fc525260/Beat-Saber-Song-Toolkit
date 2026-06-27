part of 'main.dart';

class _InlineLabeledField extends StatelessWidget {
  const _InlineLabeledField({
    required this.label,
    required this.width,
    required this.child,
  });

  final String label;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labelWidth = label.length <= 3
        ? 42.0
        : label.length <= 6
        ? 64.0
        : 82.0;
    return SizedBox(
      width: width,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _CompactCheckItem extends StatelessWidget {
  const _CompactCheckItem({
    required this.label,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!selected),
      borderRadius: BorderRadius.circular(3),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: Checkbox(
                value: selected,
                onChanged: onChanged == null
                    ? null
                    : (value) {
                        if (value != null) {
                          onChanged!(value);
                        }
                      },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _InlineAdvancedFilterGroup extends StatelessWidget {
  const _InlineAdvancedFilterGroup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: false,
      minTileHeight: 34,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(top: 4),
      title: Row(
        children: [
          Text('更多增强筛选', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ],
      ),
      children: [Align(alignment: Alignment.centerLeft, child: child)],
    );
  }
}

class _PageSizeField extends StatelessWidget {
  const _PageSizeField({
    required this.pageSize,
    required this.busy,
    required this.onChanged,
  });

  final int pageSize;
  final bool busy;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return _InlineLabeledField(
      label: '每页',
      width: 170,
      child: DropdownButtonFormField<int>(
        initialValue: pageSize,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 10, child: Text('10')),
          DropdownMenuItem(value: 20, child: Text('20')),
          DropdownMenuItem(value: 50, child: Text('50')),
          DropdownMenuItem(value: 100, child: Text('100')),
        ],
        onChanged: busy
            ? null
            : (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
      ),
    );
  }
}

class _CompactTextField extends StatelessWidget {
  const _CompactTextField({
    required this.controller,
    required this.enabled,
    required this.width,
    required this.label,
    required this.hintText,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final double width;
  final String label;
  final String hintText;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _InlineLabeledField(
      label: label,
      width: width,
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          hintText: hintText,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

class _CompactNumberField extends StatelessWidget {
  const _CompactNumberField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return _InlineLabeledField(
      label: label,
      width: 170,
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: '0',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => onSubmitted(),
      ),
    );
  }
}

class _SearchOrderField extends StatelessWidget {
  const _SearchOrderField({
    required this.searchOrder,
    required this.busy,
    required this.onChanged,
  });

  final BeatSaverSearchOrder searchOrder;
  final bool busy;
  final ValueChanged<BeatSaverSearchOrder> onChanged;

  @override
  Widget build(BuildContext context) {
    return _InlineLabeledField(
      label: '排序',
      width: 210,
      child: DropdownButtonFormField<BeatSaverSearchOrder>(
        initialValue: searchOrder,
        decoration: const InputDecoration(border: OutlineInputBorder()),
        items: BeatSaverSearchOrder.values
            .map(
              (order) => DropdownMenuItem(
                value: order,
                child: Text(_searchOrderLabel(order)),
              ),
            )
            .toList(growable: false),
        onChanged: busy
            ? null
            : (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({
    required this.title,
    required this.child,
    this.initiallyExpanded = false,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        minTileHeight: 40,
        tilePadding: const EdgeInsets.symmetric(horizontal: 10),
        childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        title: Text(title, style: Theme.of(context).textTheme.titleSmall),
        children: [Align(alignment: Alignment.centerLeft, child: child)],
      ),
    );
  }
}
