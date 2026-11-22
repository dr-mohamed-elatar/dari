/// التحقق المصري الكامل: الرقم القومي، الهاتف، الأسماء، ومنع الإدخال الخاطئ.
/// كل الدوال نقية (بدون واجهة) لتسهيل الاختبار.

/// نتيجة تحقق الرقم القومي
class NationalIdResult {
  final bool valid;
  final String? error; // رسالة عربية عند الرفض
  final DateTime? birthDate;
  final String? gender; // 'ذكر' / 'أنثى'
  final String? governorate;
  const NationalIdResult.valid({this.birthDate, this.gender, this.governorate})
      : valid = true,
        error = null;
  const NationalIdResult.invalid(this.error)
      : valid = false,
        birthDate = null,
        gender = null,
        governorate = null;
}

/// تطبيع الأرقام العربية-الهندية (٠١٢٣...) إلى أرقام لاتينية
String normalizeDigits(String input) {
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final b = StringBuffer();
  for (final ch in input.codeUnits) {
    final c = String.fromCharCode(ch);
    final i = eastern.indexOf(c);
    final j = persian.indexOf(c);
    if (i >= 0) {
      b.write(i);
    } else if (j >= 0) {
      b.write(j);
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

/// أكواد المحافظات المصرية (الرقمان 8-9 في الرقم القومي)
const Map<String, String> kGovernorates = {
  '01': 'القاهرة',
  '02': 'الإسكندرية',
  '03': 'بورسعيد',
  '04': 'السويس',
  '11': 'دمياط',
  '12': 'الدقهلية',
  '13': 'الشرقية',
  '14': 'القليوبية',
  '15': 'كفر الشيخ',
  '16': 'الغربية',
  '17': 'المنوفية',
  '18': 'البحيرة',
  '19': 'الإسماعيلية',
  '21': 'الجيزة',
  '22': 'بني سويف',
  '23': 'الفيوم',
  '24': 'المنيا',
  '25': 'أسيوط',
  '26': 'سوهاج',
  '27': 'قنا',
  '28': 'أسوان',
  '29': 'الأقصر',
  '31': 'البحر الأحمر',
  '32': 'الوادي الجديد',
  '33': 'مطروح',
  '34': 'شمال سيناء',
  '35': 'جنوب سيناء',
  '88': 'خارج الجمهورية',
};

/// المتحقق العميق للرقم القومي المصري (يُستخدم في كل المدخلات)
NationalIdResult validateEgyptianNationalId(String raw) {
  var s = normalizeDigits(raw);
  // تجاهل عدّاد مثل «X/14» قبل تجريد الرموز
  s = s.replaceAll(RegExp(r'[xX]\s*/\s*\d{1,2}'), '');
  s = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (s.length != 14) {
    return const NationalIdResult.invalid('الرقم القومي يجب أن يكون 14 رقمًا بالضبط');
  }
  final century = s[0];
  if (century != '2' && century != '3') {
    return const NationalIdResult.invalid('أول رقم يجب أن يكون 2 (مواليد 1900) أو 3 (مواليد 2000)');
  }
  final year = int.parse(s.substring(1, 3));
  final month = int.parse(s.substring(3, 5));
  final day = int.parse(s.substring(5, 7));
  final fullYear = (century == '2' ? 1900 : 2000) + year;
  // تاريخ ميلاد حقيقي موجود (يرفض 31 فبراير مثلًا)
  DateTime birth;
  try {
    birth = DateTime(fullYear, month, day);
    if (birth.year != fullYear || birth.month != month || birth.day != day) {
      return const NationalIdResult.invalid('تاريخ الميلاد غير موجود');
    }
  } catch (_) {
    return const NationalIdResult.invalid('تاريخ الميلاد غير موجود');
  }
  final now = DateTime.now();
  if (birth.isAfter(now)) {
    return const NationalIdResult.invalid('تاريخ الميلاد في المستقبل');
  }
  if (fullYear < 1900 || fullYear > now.year) {
    return const NationalIdResult.invalid('سنة الميلاد خارج النطاق');
  }
  // كود المحافظة
  final govCode = s.substring(7, 9);
  final gov = kGovernorates[govCode];
  if (gov == null) {
    return const NationalIdResult.invalid('كود المحافظة غير موجود');
  }
  // النوع من فردية/زوجية الرقم قبل الأخير
  final gender = int.parse(s[12]) % 2 == 1 ? 'ذكر' : 'أنثى';
  // رفض الأنماط الوهمية
  if (RegExp(r'^(.)\1{13}$').hasMatch(s)) {
    return const NationalIdResult.invalid('الرقم القومي غير صالح (نمط وهمي)');
  }
  final distinct = s.split('').toSet().length;
  if (distinct < 3) {
    return const NationalIdResult.invalid('الرقم القومي غير صالح (أرقام متشابهة)');
  }
  if (RegExp(r'(.)\1{7,}').hasMatch(s)) {
    return const NationalIdResult.invalid('الرقم القومي غير صالح (تكرار مبالغ فيه)');
  }
  return NationalIdResult.valid(birthDate: birth, gender: gender, governorate: gov);
}

/// الهاتف المصري: 11 رقمًا، يبدأ بـ 01 وبادئة شبكة معروفة
String? validateEgyptianPhone(String raw) {
  final s = normalizeDigits(raw).replaceAll(RegExp(r'[^0-9]'), '');
  if (s.length != 11 || !s.startsWith('01')) {
    return 'رقم الهاتف يجب أن يكون 11 رقمًا ويبدأ بـ 01';
  }
  final prefix = s.substring(0, 3);
  const prefixes = {'010': 'فودافون', '011': 'اتصالات', '012': 'أورانج', '015': 'وي'};
  if (!prefixes.containsKey(prefix)) {
    return 'البادئة غير معروفة. المسموح: 010 / 011 / 012 / 015';
  }
  return null; // صالح
}

/// تنقية الأسماء والحقول النصية: إزالة أي رموز غير الحروف العربية/اللاتينية
/// والمسافات، وضغط المسافات المتكررة.
String sanitizeName(String raw) {
  var s = raw.replaceAll(RegExp(r"[^؀-ۿa-zA-Z\s]"), '');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

String? validatePersonName(String raw, {String label = 'الاسم'}) {
  final s = sanitizeName(raw);
  if (s.length < 2) return '$label: حرفان على الأقل';
  return null;
}

String? validateAddress(String raw) {
  if (raw.trim().length < 3) return 'العنوان: 3 أحرف على الأقل';
  return null;
}

String? validateRelation(String raw) {
  final s = sanitizeName(raw);
  if (s.length < 2) return 'صلة الضامن: حرفان على الأقل';
  return null;
}
