import 'package:cel_bridge/cel_bridge.dart';
import 'package:flutter/material.dart';

import 'workbench_theme.dart';

final class WorkbenchHeader extends StatelessWidget {
  const WorkbenchHeader({super.key, required this.runtime});

  final Future<CelRuntime> runtime;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const WorkbenchBrandMark(),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'cel / bridge',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'A small workbench for checking CEL rules across runtimes.',
                style: TextStyle(color: workbenchMutedInk),
              ),
            ],
          ),
        ),
        FutureBuilder<CelRuntime>(
          future: runtime,
          builder: (context, snapshot) =>
              WorkbenchStatusTag(ready: snapshot.hasData),
        ),
      ],
    );
  }
}

final class WorkbenchBrandMark extends StatelessWidget {
  const WorkbenchBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: workbenchInk,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Text(
          '↗',
          style: TextStyle(
            color: workbenchOrange,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

final class WorkbenchStatusTag extends StatelessWidget {
  const WorkbenchStatusTag({super.key, required this.ready});

  final bool ready;

  @override
  Widget build(BuildContext context) {
    final color = ready ? workbenchTeal : workbenchMutedInk;
    return DecoratedBox(
      key: ValueKey(ready ? 'runtime-ready' : 'runtime-connecting'),
      decoration: BoxDecoration(
        color: workbenchSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: workbenchLine),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              ready ? 'RUNTIME READY' : 'CONNECTING',
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class WorkbenchPanel extends StatelessWidget {
  const WorkbenchPanel({
    super.key,
    required this.title,
    required this.marker,
    required this.child,
  });

  final String title;
  final String marker;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: workbenchSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: workbenchLine),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180E252F),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  marker,
                  style: const TextStyle(
                    color: workbenchOrange,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Container(height: 1, color: workbenchLine)),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: workbenchInk,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

final class WorkbenchCodeField extends StatelessWidget {
  const WorkbenchCodeField({
    super.key,
    required this.controller,
    required this.minLines,
    required this.maxLines,
  });

  final TextEditingController controller;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 13,
        height: 1.45,
        color: workbenchInk,
      ),
      cursorColor: workbenchOrange,
      decoration: const InputDecoration(isDense: true),
    );
  }
}

final class WorkbenchFieldCaption extends StatelessWidget {
  const WorkbenchFieldCaption(this.text, {super.key, required this.hint});

  final String text;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          text,
          style: const TextStyle(
            color: workbenchInk,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            hint,
            style: const TextStyle(color: workbenchMutedInk, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

final class WorkbenchRuntimeLine extends StatelessWidget {
  const WorkbenchRuntimeLine({
    super.key,
    this.info,
    this.error,
    this.loading = false,
  });

  final CelRuntimeInfo? info;
  final String? error;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (loading) return const WorkbenchWaitingText('Initializing runtime…');
    if (error != null) {
      return WorkbenchMessageLine(
        icon: Icons.error_outline,
        color: workbenchOrange,
        text: error!,
      );
    }
    return Row(
      children: [
        const Icon(Icons.verified_rounded, color: workbenchTeal, size: 18),
        const SizedBox(width: 8),
        Text(
          'runtime ${info!.runtimeVersion}',
          style: const TextStyle(
            color: workbenchInk,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          'cel-go ${info!.celGoVersion}',
          style: const TextStyle(
            color: workbenchMutedInk,
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

final class WorkbenchResultBlock extends StatelessWidget {
  const WorkbenchResultBlock({
    super.key,
    required this.label,
    required this.accent,
    required this.child,
  });

  final String label;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F6),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

final class WorkbenchMessageLine extends StatelessWidget {
  const WorkbenchMessageLine({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: workbenchInk, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

final class WorkbenchWaitingText extends StatelessWidget {
  const WorkbenchWaitingText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: workbenchMutedInk, fontSize: 13),
  );
}

final class WorkbenchMetric extends StatelessWidget {
  const WorkbenchMetric({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: workbenchMutedInk,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: workbenchInk,
            fontSize: 13,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class WorkbenchFooter extends StatelessWidget {
  const WorkbenchFooter({super.key, required this.runtime});

  final Future<CelRuntime> runtime;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'CEL-BRIDGE / EXAMPLE',
          style: TextStyle(
            color: workbenchMutedInk,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        FutureBuilder<CelRuntime>(
          future: runtime,
          builder: (context, snapshot) => Text(
            snapshot.hasData
                ? 'PROTOCOL ${snapshot.data!.info.protocolVersion}'
                : 'PROTOCOL —',
            style: const TextStyle(
              color: workbenchMutedInk,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
