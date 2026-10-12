/// Espaçamentos, raios e tamanhos de componentes extraídos do Figma.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Margem lateral das telas (conteúdo de 327px em frames de 375px).
  static const screenHorizontal = lg;
}

abstract final class AppRadius {
  static const sm = 5.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const pill = 100.0;
}

abstract final class AppSizes {
  static const buttonHeight = 48.0;
  static const inputHeight = 50.0;
  static const icon = 24.0;
  static const bottomBarHeight = 78.0;
}
