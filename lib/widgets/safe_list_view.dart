import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ListView com padding bottom automático para não ser coberta por FAB/VoiceButton
/// Resolve o problema de conteúdo oculto por botões flutuantes
class SafeListView extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool shrinkWrap;
  final bool hasFloatingButton;

  const SafeListView({
    super.key,
    required this.children,
    this.padding,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
    this.hasFloatingButton = true, // Por padrão assume que tem botão flutuante
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry effectivePadding = padding ?? EdgeInsets.zero;

    // Se tem botão flutuante, adiciona padding bottom de 80px
    if (hasFloatingButton) {
      effectivePadding = effectivePadding is EdgeInsets
          ? effectivePadding.copyWith(bottom: effectivePadding.bottom + 80)
          : EdgeInsets.only(
              left: 0,
              top: 0,
              right: 0,
              bottom: 80,
            );
    }

    return ListView(
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: effectivePadding,
      children: children,
    );
  }
}

/// ListView.builder com padding bottom automático
class SafeListViewBuilder extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool shrinkWrap;
  final bool hasFloatingButton;

  const SafeListViewBuilder({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.physics,
    this.controller,
    this.shrinkWrap = false,
    this.hasFloatingButton = true,
  });

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry effectivePadding = padding ?? EdgeInsets.zero;

    if (hasFloatingButton) {
      effectivePadding = effectivePadding is EdgeInsets
          ? effectivePadding.copyWith(bottom: effectivePadding.bottom + 80)
          : EdgeInsets.only(
              left: 0,
              top: 0,
              right: 0,
              bottom: 80,
            );
    }

    return ListView.builder(
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      padding: effectivePadding,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

/// SingleChildScrollView com padding bottom automático
class SafeSingleChildScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final ScrollController? controller;
  final bool hasFloatingButton;

  const SafeSingleChildScrollView({
    super.key,
    required this.child,
    this.padding,
    this.physics,
    this.controller,
    this.hasFloatingButton = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Adicionar padding se necessário
    if (hasFloatingButton || padding != null) {
      EdgeInsetsGeometry effectivePadding = padding ?? EdgeInsets.zero;

      if (hasFloatingButton) {
        effectivePadding = effectivePadding is EdgeInsets
            ? effectivePadding.copyWith(bottom: effectivePadding.bottom + 80)
            : EdgeInsets.only(
                left: 0,
                top: 0,
                right: 0,
                bottom: 80,
              );
      }

      content = Padding(
        padding: effectivePadding,
        child: content,
      );
    }

    return SingleChildScrollView(
      controller: controller,
      physics: physics,
      child: content,
    );
  }
}
