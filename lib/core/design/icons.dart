import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Set curado de claves de íconos para elegir al crear o editar categorías (≥ 40 claves).
const List<String> kCategoryIconKeys = [
  // Seed inicial (13)
  'fork-knife',
  'car-profile',
  'house-line',
  'heartbeat',
  'popcorn',
  'lightning',
  'graduation-cap',
  'gift',
  't-shirt',
  'package',
  'briefcase',
  'sparkle',
  'arrow-circle-down',

  // Curados adicionales (40)
  'airplane',
  'baby',
  'bank',
  'barbell',
  'bed',
  'beer-bottle',
  'bicycle',
  'book-open',
  'bus',
  'coffee',
  'coins',
  'credit-card',
  'currency-dollar',
  'device-mobile',
  'drop',
  'film-strip',
  'first-aid',
  'flower',
  'game-controller',
  'gas-pump',
  'hamburger',
  'hammer',
  'music-notes',
  'paint-brush',
  'paw-print',
  'piggy-bank',
  'pill',
  'pizza',
  'receipt',
  'shopping-bag',
  'shopping-cart',
  'tag',
  'taxi',
  'television',
  'ticket',
  'train',
  'trend-up',
  'wallet',
  'wifi-high',
  'wrench',
];

/// Mapeo estático a constantes de Phosphor Duotone para permitir tree-shaking en release.
const Map<String, PhosphorDuotoneIconData> _kCategoryIcons = {
  'fork-knife': PhosphorIconsDuotone.forkKnife,
  'car-profile': PhosphorIconsDuotone.carProfile,
  'house-line': PhosphorIconsDuotone.houseLine,
  'heartbeat': PhosphorIconsDuotone.heartbeat,
  'popcorn': PhosphorIconsDuotone.popcorn,
  'lightning': PhosphorIconsDuotone.lightning,
  'graduation-cap': PhosphorIconsDuotone.graduationCap,
  'gift': PhosphorIconsDuotone.gift,
  't-shirt': PhosphorIconsDuotone.tShirt,
  'package': PhosphorIconsDuotone.package,
  'briefcase': PhosphorIconsDuotone.briefcase,
  'sparkle': PhosphorIconsDuotone.sparkle,
  'arrow-circle-down': PhosphorIconsDuotone.arrowCircleDown,

  'airplane': PhosphorIconsDuotone.airplane,
  'baby': PhosphorIconsDuotone.baby,
  'bank': PhosphorIconsDuotone.bank,
  'barbell': PhosphorIconsDuotone.barbell,
  'bed': PhosphorIconsDuotone.bed,
  'beer-bottle': PhosphorIconsDuotone.beerBottle,
  'bicycle': PhosphorIconsDuotone.bicycle,
  'book-open': PhosphorIconsDuotone.bookOpen,
  'bus': PhosphorIconsDuotone.bus,
  'coffee': PhosphorIconsDuotone.coffee,
  'coins': PhosphorIconsDuotone.coins,
  'credit-card': PhosphorIconsDuotone.creditCard,
  'currency-dollar': PhosphorIconsDuotone.currencyDollar,
  'device-mobile': PhosphorIconsDuotone.deviceMobile,
  'drop': PhosphorIconsDuotone.drop,
  'film-strip': PhosphorIconsDuotone.filmStrip,
  'first-aid': PhosphorIconsDuotone.firstAid,
  'flower': PhosphorIconsDuotone.flower,
  'game-controller': PhosphorIconsDuotone.gameController,
  'gas-pump': PhosphorIconsDuotone.gasPump,
  'hamburger': PhosphorIconsDuotone.hamburger,
  'hammer': PhosphorIconsDuotone.hammer,
  'music-notes': PhosphorIconsDuotone.musicNotes,
  'paint-brush': PhosphorIconsDuotone.paintBrush,
  'paw-print': PhosphorIconsDuotone.pawPrint,
  'piggy-bank': PhosphorIconsDuotone.piggyBank,
  'pill': PhosphorIconsDuotone.pill,
  'pizza': PhosphorIconsDuotone.pizza,
  'receipt': PhosphorIconsDuotone.receipt,
  'shopping-bag': PhosphorIconsDuotone.shoppingBag,
  'shopping-cart': PhosphorIconsDuotone.shoppingCart,
  'tag': PhosphorIconsDuotone.tag,
  'taxi': PhosphorIconsDuotone.taxi,
  'television': PhosphorIconsDuotone.television,
  'ticket': PhosphorIconsDuotone.ticket,
  'train': PhosphorIconsDuotone.train,
  'trend-up': PhosphorIconsDuotone.trendUp,
  'wallet': PhosphorIconsDuotone.wallet,
  'wifi-high': PhosphorIconsDuotone.wifiHigh,
  'wrench': PhosphorIconsDuotone.wrench,
};

/// Devuelve el [PhosphorDuotoneIconData] asociado a la clave, o [PhosphorIconsDuotone.package] si es desconocida.
PhosphorDuotoneIconData categoryIconData(String key) {
  return _kCategoryIcons[key] ?? PhosphorIconsDuotone.package;
}

/// Widget de ícono para categorías en estilo Duotone.
/// Clave desconocida → ícono `package`.
Widget categoryIcon(String key, {double size = 24, Color? color}) {
  return PhosphorIcon(
    categoryIconData(key),
    size: size,
    color: color,
  );
}

/// Mapeo estático a constantes de Phosphor Regular para UI general.
const Map<String, PhosphorFlatIconData> _kUiIconsRegular = {
  'plus': PhosphorIconsRegular.plus,
  'x': PhosphorIconsRegular.x,
  'close': PhosphorIconsRegular.x,
  'check': PhosphorIconsRegular.check,
  'arrow-left': PhosphorIconsRegular.arrowLeft,
  'caret-down': PhosphorIconsRegular.caretDown,
  'calendar': PhosphorIconsRegular.calendar,
  'trash': PhosphorIconsRegular.trash,
  'magnifying-glass': PhosphorIconsRegular.magnifyingGlass,
  'pencil-simple': PhosphorIconsRegular.pencilSimple,
  'storefront': PhosphorIconsRegular.storefront,
  'note': PhosphorIconsRegular.note,
  'sparkle': PhosphorIconsRegular.sparkle,
  'caret-right': PhosphorIconsRegular.caretRight,
  'house': PhosphorIconsRegular.house,
  'arrows-left-right': PhosphorIconsRegular.arrowsLeftRight,
  'chart-pie-slice': PhosphorIconsRegular.chartPieSlice,
  'chart-bar': PhosphorIconsRegular.chartBar,
  'gear': PhosphorIconsRegular.gear,
  'trend-up': PhosphorIconsRegular.trendUp,
  'trend-down': PhosphorIconsRegular.trendDown,
  'funnel': PhosphorIconsRegular.funnel,
};

/// Mapeo estático a constantes de Phosphor Fill para UI general cuando está activo.
const Map<String, PhosphorFlatIconData> _kUiIconsFill = {
  'plus': PhosphorIconsFill.plus,
  'x': PhosphorIconsFill.x,
  'close': PhosphorIconsFill.x,
  'check': PhosphorIconsFill.check,
  'arrow-left': PhosphorIconsFill.arrowLeft,
  'caret-down': PhosphorIconsFill.caretDown,
  'calendar': PhosphorIconsFill.calendar,
  'trash': PhosphorIconsFill.trash,
  'magnifying-glass': PhosphorIconsFill.magnifyingGlass,
  'pencil-simple': PhosphorIconsFill.pencilSimple,
  'storefront': PhosphorIconsFill.storefront,
  'note': PhosphorIconsFill.note,
  'sparkle': PhosphorIconsFill.sparkle,
  'caret-right': PhosphorIconsFill.caretRight,
  'house': PhosphorIconsFill.house,
  'arrows-left-right': PhosphorIconsFill.arrowsLeftRight,
  'chart-pie-slice': PhosphorIconsFill.chartPieSlice,
  'chart-bar': PhosphorIconsFill.chartBar,
  'gear': PhosphorIconsFill.gear,
  'trend-up': PhosphorIconsFill.trendUp,
  'trend-down': PhosphorIconsFill.trendDown,
  'funnel': PhosphorIconsFill.funnel,
};

/// Devuelve el [IconData] de Phosphor en estilo Regular o Fill según [filled].
IconData uiIcon(String key, {bool filled = false}) {
  if (filled) {
    return _kUiIconsFill[key] ?? PhosphorIconsFill.question;
  }
  return _kUiIconsRegular[key] ?? PhosphorIconsRegular.question;
}
