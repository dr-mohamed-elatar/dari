import 'package:dari_app/logic/egyptian_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('الرقم القومي', () {
    // 28501010102331: مواليد 1985-01-01، محافظة 01 القاهرة، ذكر (رقم التسلسل 3 فردي)
    test('رقم صحيح يمر مع استخراج البيانات', () {
      final r = validateEgyptianNationalId('28501010102331');
      expect(r.valid, true);
      expect(r.birthDate, DateTime(1985, 1, 1));
      expect(r.gender, 'ذكر');
      expect(r.governorate, 'القاهرة');
    });
    test('أنثى: الرقم قبل الأخير زوجي', () {
      final r = validateEgyptianNationalId('28501010102341');
      expect(r.valid, true);
      expect(r.gender, 'أنثى');
    });
    test('يرفض أول رقم غير 2 أو 3', () {
      expect(validateEgyptianNationalId('48501010102341').valid, false);
    });
    test('يرفض 31 فبراير', () {
      expect(validateEgyptianNationalId('28502310102341').valid, false);
    });
    test('يرفض تاريخ ميلاد في المستقبل', () {
      final future = DateTime.now().year + 1;
      final c = future >= 2000 ? '3' : '2';
      final yy = (future % 100).toString().padLeft(2, '0');
      expect(validateEgyptianNationalId('$c${yy}0101012341').valid, false);
    });
    test('يرفض كود محافظة غير موجود', () {
      expect(validateEgyptianNationalId('28501019902341').valid, false);
    });
    test('يرفض تكرار نفس الرقم 14 مرة', () {
      expect(validateEgyptianNationalId('22222222222222').valid, false);
    });
    test('يرفض أقل من 3 أرقام مختلفة', () {
      expect(validateEgyptianNationalId('21212121212121').valid, false);
    });
    test('يطبّع الأرقام العربية-الهندية', () {
      expect(normalizeDigits('٢٨٥٠١٠١٠١٠٢٣٤١'), '28501010102341');
      expect(validateEgyptianNationalId('٢٨٥٠١٠١٠١٠٢٣٤١').valid, true);
    });
    test('يتجاهل الرموز وعدّاد X/14', () {
      expect(validateEgyptianNationalId('285-0101-0102341 X/14').valid, true);
    });
    test('يرفض الطول الخاطئ', () {
      expect(validateEgyptianNationalId('2850101010234').valid, false);
      expect(validateEgyptianNationalId('285010101023411').valid, false);
    });
  });

  group('الهاتف', () {
    test('الشبكات الأربع مقبولة', () {
      for (final p in ['010', '011', '012', '015']) {
        expect(validateEgyptianPhone('${p}12345678'), null);
      }
    });
    test('يرفض بادئة غير معروفة', () {
      expect(validateEgyptianPhone('01312345678'), isNotNull);
    });
    test('يرفض الطول الخاطئ', () {
      expect(validateEgyptianPhone('0101234567'), isNotNull);
      expect(validateEgyptianPhone('010123456789'), isNotNull);
    });
    test('يطبّع الأرقام العربية', () {
      expect(validateEgyptianPhone('٠١٠١٢٣٤٥٦٧٨'), null);
    });
  });

  group('الأسماء', () {
    test('تنقية الرموز وضغط المسافات', () {
      expect(sanitizeName('  محمد   \$# علي!! '), 'محمد علي');
      expect(sanitizeName('Ahmed123 Ali'), 'Ahmed Ali');
    });
    test('حد أدنى حرفان', () {
      expect(validatePersonName('م'), isNotNull);
      expect(validatePersonName('مح'), null);
    });
    test('العنوان 3 أحرف وصلة الضامن حرفان', () {
      expect(validateAddress('ش'), isNotNull);
      expect(validateAddress('شارع'), null);
      expect(validateRelation('أ'), isNotNull);
      expect(validateRelation('أخ'), null);
    });
  });
}
