import 'package:flutter/material.dart';
import 'aurora_tokens.dart';

class MonoText extends StatelessWidget {
  const MonoText(this.data, {super.key, this.style, this.textAlign});
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => Text(
    data,
    textAlign: textAlign,
    style: TextStyle(
      fontFamily: 'JetBrains Mono',
      fontFeatures: const [FontFeature.tabularFigures()],
      color: context.aurora.tx,
    ).merge(style),
  );
}

class CapText extends StatelessWidget {
  const CapText(this.data, {super.key, this.style});
  final String data;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => Text(
    data,
    style: TextStyle(
      fontFamily: 'Space Grotesk',
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      color: context.aurora.tx3,
      fontSize: 10,
    ).merge(style),
  );
}

enum AdminTone { green, amber, red, blue, neutral }

Color toneColor(AuroraTokens t, AdminTone tone) => switch (tone) {
  AdminTone.green => t.hi,
  AdminTone.amber => t.wk,
  AdminTone.red => t.pr,
  AdminTone.blue => t.gd,
  AdminTone.neutral => t.tx3,
};

class AdminTag extends StatelessWidget {
  const AdminTag(this.label, {super.key, this.tone = AdminTone.neutral});
  final String label;
  final AdminTone tone;
  @override
  Widget build(BuildContext context) {
    final t = context.aurora;
    final c = toneColor(t, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone == AdminTone.neutral ? t.field : c.withValues(alpha: .09),
        border: Border.all(
          color: tone == AdminTone.neutral ? t.edge : c.withValues(alpha: .3),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: MonoText(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: .3,
          color: c,
        ),
      ),
    );
  }
}

class AdminLed extends StatelessWidget {
  const AdminLed({super.key, this.tone = AdminTone.green, this.pulse = false});
  final AdminTone tone;
  final bool pulse;
  @override
  Widget build(BuildContext context) {
    final c = toneColor(context.aurora, tone);
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: pulse
            ? [BoxShadow(color: c.withValues(alpha: .5), blurRadius: 9)]
            : null,
      ),
    );
  }
}

enum AdminButtonKind { primary, secondary, destructive, text }

class AdminButton extends StatelessWidget {
  const AdminButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.kind = AdminButtonKind.secondary,
    this.icon,
    this.fullWidth = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final AdminButtonKind kind;
  final IconData? icon;
  final bool fullWidth;
  @override
  Widget build(BuildContext context) {
    final t = context.aurora;
    final color = kind == AdminButtonKind.destructive
        ? t.pr
        : kind == AdminButtonKind.primary
        ? t.gd
        : kind == AdminButtonKind.text
        ? t.gd
        : t.tx;
    final fill = kind == AdminButtonKind.primary
        ? t.gd
        : kind == AdminButtonKind.destructive
        ? t.pr.withValues(alpha: .1)
        : kind == AdminButtonKind.text
        ? Colors.transparent
        : t.field;
    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 15),
        label: Text(label),
        style: TextButton.styleFrom(
          foregroundColor: kind == AdminButtonKind.primary ? t.bg : color,
          backgroundColor: fill,
          disabledForegroundColor: t.tx4,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: kind == AdminButtonKind.text
                  ? Colors.transparent
                  : kind == AdminButtonKind.primary
                  ? t.gd
                  : kind == AdminButtonKind.destructive
                  ? t.pr.withValues(alpha: .4)
                  : t.edge,
            ),
          ),
        ),
      ),
    );
  }
}

class AdminPanel extends StatelessWidget {
  const AdminPanel({
    super.key,
    this.title,
    this.trailing,
    required this.child,
    this.hot = false,
    this.beam = false,
    this.padding = const EdgeInsets.all(20),
  });
  final String? title;
  final Widget? trailing;
  final Widget child;
  final bool hot, beam;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final t = context.aurora;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.glass,
            t.glass.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .03
                  : .72,
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: hot ? t.gd.withValues(alpha: .4) : t.edge),
        boxShadow: hot
            ? [BoxShadow(color: t.gd.withValues(alpha: .10), blurRadius: 32)]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (beam) Container(height: 2, color: t.gd),
          if (title != null)
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: t.edge2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: t.tx,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class AdminStat extends StatelessWidget {
  const AdminStat({
    super.key,
    required this.label,
    required this.value,
    required this.footer,
    this.danger = false,
    this.neutral = false,
  });
  final String label, value;
  final Widget? footer;
  final bool danger, neutral;
  @override
  Widget build(BuildContext context) {
    final t = context.aurora;
    return Container(
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.glass,
            t.glass.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? .03
                  : .72,
            ),
          ],
        ),
        border: Border.all(color: danger ? t.pr.withValues(alpha: .4) : t.edge),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (danger) Container(height: 3, color: t.pr),
          CapText(label.toUpperCase()),
          const SizedBox(height: 17),
          MonoText(
            value,
            style: TextStyle(
              color: danger ? t.pr : t.tx,
              fontSize: danger ? 38 : 31,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}

class AdminModal {
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool destructive = false,
    Widget? content,
  }) async {
    final t = context.aurora;
    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            backgroundColor: t.knob,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
              side: BorderSide(color: t.edge),
            ),
            title: Text(
              title,
              style: TextStyle(fontFamily: 'Space Grotesk', color: t.tx),
            ),
            content: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(color: t.tx2, fontSize: 12, height: 1.5),
                  ),
                  if (content != null) ...[const SizedBox(height: 18), content],
                ],
              ),
            ),
            actions: [
              AdminButton('Cancel', onPressed: () => Navigator.pop(c, false)),
              AdminButton(
                confirmLabel,
                kind: destructive
                    ? AdminButtonKind.destructive
                    : AdminButtonKind.primary,
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> drawer(BuildContext context, Widget child) {
    final t = context.aurora;
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close details',
      barrierColor: Colors.black54,
      pageBuilder: (c, _, __) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: t.knob,
          child: Container(
            width: 345,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: t.edge)),
            ),
            child: SafeArea(child: child),
          ),
        ),
      ),
    );
  }
}

class AdminToast {
  static void show(BuildContext context, String message) {
    final t = context.aurora;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: t.tx, fontSize: 11)),
        backgroundColor: t.knob,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}

class AdminCallout extends StatelessWidget {
  const AdminCallout({
    super.key,
    required this.title,
    required this.description,
    this.tone = AdminTone.amber,
  });
  final String title, description;
  final AdminTone tone;
  @override
  Widget build(BuildContext context) {
    final t = context.aurora, c = toneColor(t, tone);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .07),
        border: Border.all(color: c.withValues(alpha: .3)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            tone == AdminTone.red
                ? Icons.shield_outlined
                : tone == AdminTone.blue
                ? Icons.lock_outline
                : Icons.info_outline,
            size: 18,
            color: c,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: c,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: t.tx2, fontSize: 11, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
