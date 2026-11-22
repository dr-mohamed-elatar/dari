import 'package:dari_app/logic/installment_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 1, 15);

  test('أول قسط = تاريخ الإنشاء + شهر', () {
    final p = computePlan(total: 12000, downPayment: 2000, months: 10, startDate: start);
    expect(p.schedule.first.dueDate, DateTime(2026, 2, 15));
    expect(p.schedule.length, 10);
  });

  test('القسط الأخير = المتبقي بالظبط (لا فرق تقريب)', () {
    final p = computePlan(total: 10000, downPayment: 1000, months: 7, startDate: start);
    final sum = p.schedule.fold<double>(0, (a, b) => a + b.amount);
    expect(sum, closeTo(p.totalWithInterest, 0.001));
    expect(p.lastInstallment,
        round2(p.totalWithInterest - p.monthly * (p.schedule.length - 1)));
  });

  test('الفائدة نسبة على المبلغ الممول وتظهر كربح', () {
    final p = computePlan(
        total: 10000, downPayment: 2000, months: 8, interestPct: 10, startDate: start);
    expect(p.financed, 8000);
    expect(p.interestAmount, 800);
    expect(p.totalWithInterest, 8800);
  });

  test('مدة خارج 1-60 مرفوضة', () {
    expect(() => computePlan(total: 1000, downPayment: 0, months: 0, startDate: start),
        throwsArgumentError);
    expect(() => computePlan(total: 1000, downPayment: 0, months: 61, startDate: start),
        throwsArgumentError);
  });

  test('مقدم أقل من الحد الأدنى المئوي يرفض بخطأ', () {
    expect(
        validateDownPayment(total: 10000, downPayment: 1000, minDownPct: 20), isNotNull);
    expect(validateDownPayment(total: 10000, downPayment: 2500, minDownPct: 20), null);
  });

  test('المقدم يُصحح إلى أرضية الإجمالي', () {
    expect(clampDownPayment(10000, 15000), 10000);
    expect(clampDownPayment(10000, -50), 0);
  });

  test('لو القسط الأخير سالب أو صفر لا يُعدَّل الجدول', () {
    final p = computePlan(total: 900, downPayment: 0, months: 3, startDate: start);
    expect(p.schedule.every((r) => r.amount == 300), true);
  });

  test('ترحيل شهر كامل عند عقد قديم أول قسطه بتاريخ البدء', () {
    final p = computePlan(
        total: 1200, downPayment: 0, months: 3, startDate: start, shiftOneMonth: true);
    expect(p.schedule.first.dueDate, DateTime(2026, 3, 15));
  });

  test('31 يناير + شهر = آخر فبراير', () {
    final d = addMonth(DateTime(2026, 1, 31), 1);
    expect(d, DateTime(2026, 2, 28));
  });

  test('الخطط البديلة تحترم الحد الأدنى للمقدم', () {
    final plans = alternativePlans(
        total: 10000, downPayment: 2000, months: 10, minDownPct: 20, startDate: start);
    expect(plans, isNotEmpty);
    for (final p in plans) {
      expect(p.financed, lessThanOrEqualTo(10000 - 2000));
    }
  });
}
