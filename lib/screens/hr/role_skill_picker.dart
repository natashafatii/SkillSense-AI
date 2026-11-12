import 'package:skillsense_ai/constants/adaptive_colors.dart';
import '../../widgets/recruiter_button_style.dart';
import 'package:flutter/material.dart';

import 'role_skill_catalog.dart';

typedef _SkillGroup = ({String category, String heading, List<String> names});

class RoleSkillPicker extends StatefulWidget {
  const RoleSkillPicker({super.key, required this.initialSkills});

  static const maxSkills = 20;
  final List<String> initialSkills;

  @override
  State<RoleSkillPicker> createState() => _RoleSkillPickerState();
}

class _RoleSkillPickerState extends State<RoleSkillPicker> {
  static const _primary = Color(0xFF3658DB);
  static const _muted = Color(0xFF68758D);
  static const _line = Color(0xFFE2E7F0);
  static const _all = 'All';
  static const _customCategory = 'Custom';
  static const _maxSkills = RoleSkillPicker.maxSkills;
  static const _maxCustomLength = 60;
  static final _groups = <_SkillGroup>[
    for (final category in roleSkillCatalog.entries)
      for (final group in category.value.entries)
        (
          category: category.key,
          heading: group.key,
          names: group.value.split('|'),
        ),
  ];
  static final _catalogNames = {
    for (final group in _groups)
      for (final name in group.names) name.toLowerCase(): name,
  };
  static final _categoryCounts = {
    _all: _catalogNames.length,
    for (final category in roleSkillCatalog.entries)
      category.key: category.value.values.fold<int>(
        0,
        (count, names) => count + names.split('|').length,
      ),
  };

  final _search = TextEditingController();
  final _customInput = TextEditingController();
  final _catalogScroll = ScrollController();
  late final _selected = {
    for (final name in widget.initialSkills) name.toLowerCase(): name,
  };
  late final _custom = Map.of(_selected)
    ..removeWhere((key, _) => _catalogNames.containsKey(key));
  String _category = _all;
  bool _onlySelected = false;

  bool get _atLimit => _selected.length >= _maxSkills;

  @override
  void dispose() {
    _search.dispose();
    _customInput.dispose();
    _catalogScroll.dispose();
    super.dispose();
  }

  void _resetCatalog(VoidCallback update) {
    if (_catalogScroll.hasClients) _catalogScroll.jumpTo(0);
    setState(update);
  }

  void _toggle(String name) {
    final key = name.toLowerCase();
    setState(() {
      if (_selected.containsKey(key)) {
        _selected.remove(key);
      } else if (!_atLimit) {
        _selected[key] = name;
      }
    });
  }

  void _addCustom(String value) {
    final name = value.trim();
    final key = name.toLowerCase();
    if (name.isEmpty || name.length > _maxCustomLength || _atLimit) return;
    setState(() {
      final label = _catalogNames[key] ?? _custom.putIfAbsent(key, () => name);
      _selected.putIfAbsent(key, () => label);
      _customInput.clear();
    });
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: context.themeSurface(Colors.white),
    surfaceTintColor: Colors.transparent,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
    insetPadding: const EdgeInsets.all(12),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1030, maxHeight: 858),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final horizontal = wide ? 28.0 : 16.0;
          final filters = _filters(horizontal, wide);
          final header = _header(horizontal);
          final short = constraints.maxHeight < 420;
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Column(
              children: [
                if (!short) ...[header, filters],
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _catalog(
                          horizontal,
                          leading: short ? [header, filters] : const [],
                        ),
                      ),
                      if (wide && !short) _selectionPanel(),
                    ],
                  ),
                ),
                _footer(horizontal, wide),
              ],
            ),
          );
        },
      ),
    ),
  );

  Widget _header(double horizontal) => Padding(
    padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: context.themeSurface(const Color(0xFFEEF1FF)),
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              child: Padding(
                padding: EdgeInsets.all(9),
                child: Icon(Icons.star_border_rounded, color: _primary),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Add Skills',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Close without saving',
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close, color: context.themeForeground(_muted)),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          'Search, explore categories, and select up to $_maxSkills skills.',
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 13,
          ),
        ),
      ],
    ),
  );

  Widget _filters(double horizontal, bool wide) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.themeOutline(_line))),
    ),
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: Column(
        children: [
          TextField(
            key: const Key('role-skill-picker-search'),
            controller: _search,
            autofocus: wide,
            onChanged: (_) => _resetCatalog(() {}),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.search,
                color: context.themeForeground(_muted),
              ),
              hintText: 'Search skills, e.g. Python, React, Flutter',
              isDense: true,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(11)),
              ),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () => _resetCatalog(_search.clear),
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final category in _categoryCounts.keys)
                        _categoryTab(
                          category,
                          _categoryCounts[category]! +
                              (_all == category ? _custom.length : 0),
                        ),
                      if (_custom.isNotEmpty)
                        _categoryTab(_customCategory, _custom.length),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (wide)
                FilterChip(
                  label: const Text('Selected only'),
                  selected: _onlySelected,
                  onSelected: (value) =>
                      _resetCatalog(() => _onlySelected = value),
                )
              else
                IconButton(
                  tooltip: 'Selected only',
                  isSelected: _onlySelected,
                  onPressed: () =>
                      _resetCatalog(() => _onlySelected = !_onlySelected),
                  icon: const Icon(Icons.check_box_outline_blank),
                  selectedIcon: const Icon(Icons.check_box, color: _primary),
                ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _categoryTab(String category, int count) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: _category == category ? _primary : Colors.transparent,
          width: 2,
        ),
      ),
    ),
    child: TextButton(
      onPressed: () => _resetCatalog(() => _category = category),
      style: TextButton.styleFrom(
        foregroundColor: _category == category
            ? _primary
            : context.themeForeground(_muted),
      ),
      child: Text('$category $count'),
    ),
  );

  Widget _catalog(double horizontal, {required List<Widget> leading}) {
    final text = _search.text.trim();
    final query = text.toLowerCase();
    final groups = <_SkillGroup>[];
    var count = 0;
    for (final group in [
      ..._groups,
      (
        category: _customCategory,
        heading: 'Custom skills',
        names: _custom.values.toList(),
      ),
    ]) {
      if (_category != _all && _category != group.category) continue;
      final names = group.names.where((name) {
        final key = name.toLowerCase();
        return key.contains(query) &&
            (!_onlySelected || _selected.containsKey(key));
      }).toList();
      if (names.isEmpty) continue;
      groups.add((
        category: group.category,
        heading: group.heading,
        names: names,
      ));
      count += names.length;
    }
    final canAdd =
        !_onlySelected &&
        !_atLimit &&
        query.isNotEmpty &&
        text.length <= _maxCustomLength &&
        !_catalogNames.containsKey(query) &&
        !_custom.containsKey(query);
    final summary = Row(
      children: [
        Expanded(
          child: Text(
            query.isNotEmpty
                ? 'Results for “$text”'
                : _onlySelected
                ? 'Your selected skills'
                : _category == _all
                ? 'Explore all skills'
                : '$_category skills',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          '$count skills',
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 12,
          ),
        ),
      ],
    );
    return CustomScrollView(
      controller: _catalogScroll,
      slivers: [
        for (final widget in leading) SliverToBoxAdapter(child: widget),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 24),
          sliver: SliverList.builder(
            itemCount: groups.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) return summary;
              if (index <= groups.length) return _skillGroup(groups[index - 1]);
              return Column(
                children: [
                  if (groups.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'No matching skills',
                        style: TextStyle(
                          color: context.themeForeground(_muted),
                        ),
                      ),
                    ),
                  if (canAdd)
                    OutlinedButton.icon(
                      onPressed: () => _addCustom(text),
                      icon: const Icon(Icons.add),
                      label: Text('Add “$text”'),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _skillGroup(_SkillGroup group) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${group.heading.toUpperCase()}  ${group.names.length}',
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [for (final name in group.names) _skillOption(name)],
        ),
      ],
    ),
  );

  Widget _skillOption(String name) {
    final selected = _selected.containsKey(name.toLowerCase());
    return FilterChip(
      key: ValueKey('role-skill-$name'),
      label: Text(name),
      selected: selected,
      labelStyle: selected ? const TextStyle(color: Colors.white) : null,
      checkmarkColor: Colors.white,
      selectedColor: _primary,
      backgroundColor: context.themeSurface(Colors.white),
      side: BorderSide(
        color: selected ? _primary : context.themeOutline(_line),
      ),
      shape: const StadiumBorder(),
      onSelected: selected || !_atLimit ? (_) => _toggle(name) : null,
    );
  }

  Widget _selectionPanel() => Container(
    width: 258,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.themeSurface(const Color(0xFFFAFBFF)),
      border: Border(left: BorderSide(color: context.themeOutline(_line))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Your selection',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${_selected.length} / $_maxSkills',
              style: const TextStyle(color: _primary),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Tap a skill to add or remove it.',
          style: TextStyle(
            color: context.themeForeground(_muted),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _selected.isEmpty
              ? Center(
                  child: Text(
                    'Selected skills will appear here before saving.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.themeForeground(_muted)),
                  ),
                )
              : ListView(
                  children: [
                    for (final name in _selected.values)
                      Card(
                        elevation: 0,
                        color: context.themeSurface(Colors.white),
                        child: ListTile(
                          dense: true,
                          title: Text(name),
                          trailing: IconButton(
                            tooltip: 'Remove $name',
                            onPressed: () => _toggle(name),
                            icon: const Icon(Icons.close, size: 16),
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        Divider(color: context.themeOutline(_line)),
        const Text(
          'Can’t find a skill? Add your own',
          style: TextStyle(fontSize: 12),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customInput,
                maxLength: _maxCustomLength,
                enabled: !_atLimit,
                onSubmitted: _addCustom,
                decoration: const InputDecoration(
                  hintText: 'Custom skill name',
                  counterText: '',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Add custom skill',
              onPressed: _atLimit ? null : () => _addCustom(_customInput.text),
              icon: const Icon(Icons.add, color: _primary),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _footer(double horizontal, bool wide) {
    final status = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${_selected.length} selected',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${(_maxSkills - _selected.length).clamp(0, _maxSkills)} more allowed',
              style: TextStyle(color: context.themeForeground(_muted)),
            ),
            TextButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => setState(_selected.clear),
              child: const Text('Clear all'),
            ),
          ],
        ),
        SizedBox(
          width: 230,
          child: LinearProgressIndicator(
            value: (_selected.length / _maxSkills).clamp(0.0, 1.0),
            color: _primary,
            backgroundColor: context.themeSurface(_line),
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ],
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 14);
    final actions = Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(padding: buttonPadding),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('role-skill-picker-save'),
          onPressed: () => Navigator.of(context).pop(_selected.values.toList()),
          style: RecruiterButtonStyle.primary(
            FilledButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: buttonPadding,
            ),
          ),
          child: const Text('Save skills'),
        ),
      ],
    );
    return Container(
      padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.themeOutline(_line))),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(child: status),
                actions,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                status,
                const SizedBox(height: 6),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            ),
    );
  }
}
