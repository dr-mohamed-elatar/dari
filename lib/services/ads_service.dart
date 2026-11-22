import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart' hide AppState;

/// إعلانات AdMob التجريبية حتى يُفعَّل حساب AdMob الحقيقي
class AdsService {
  static const String testAppId = 'ca-app-pub-3940256099942544~1452512354';
  static const String testBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';

  static bool get supported =>
      !kIsWeb && Platform.environment['FLUTTER_TEST'] != 'true';

  static Future<void> init() async {
    if (!supported) return;
    await MobileAds.instance.initialize();
  }

  static BannerAd? createBanner(void Function() onLoaded) {
    if (!supported) return null;
    final ad = BannerAd(
      adUnitId: testBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(onAdLoaded: (_) => onLoaded()),
    );
    ad.load();
    return ad;
  }
}
