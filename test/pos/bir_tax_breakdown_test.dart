import 'package:flutter_test/flutter_test.dart';
import 'package:pickleball_app/core/utils/bir_tax_breakdown.dart';

void main() {
  group('Philippine BIR EOPT & Statutory Tax Breakdown Engine', () {
    test('Regular sale with 12% VAT computes accurately', () {
      final tax = BirTaxBreakdown.compute(
        gross: 400.00,
        discountType: 'none',
      );

      expect(tax.grossSubtotal, 400.00);
      expect(tax.vatableSales, 357.14);
      expect(tax.vatAmount, 42.86);
      expect(tax.vatExemptSales, 0.0);
      expect(tax.discountAmount, 0.0);
      expect(tax.netPayable, 400.00);
      expect(tax.vatableSales + tax.vatAmount, 400.00);
    });

    test('Senior Citizen 20% discount (RA 9994) removes VAT and computes statutory net', () {
      final tax = BirTaxBreakdown.compute(
        gross: 400.00,
        discountType: 'senior_citizen',
      );

      // 1. Remove 12% VAT: 400 / 1.12 = 357.14
      expect(tax.vatExemptSales, 357.14);
      // 2. 20% statutory discount: 357.14 * 0.20 = 71.43
      expect(tax.discountAmount, 71.43);
      // 3. Net payable: 357.14 - 71.43 = 285.71
      expect(tax.netPayable, 285.71);
      expect(tax.vatableSales, 0.0);
      expect(tax.vatAmount, 0.0);
      expect(tax.grossSubtotal, 400.00);
    });

    test('Person with Disability (PWD) 20% discount (RA 10754) matches Senior calculation', () {
      final tax = BirTaxBreakdown.compute(
        gross: 240.00,
        discountType: 'pwd',
      );

      // 240 / 1.12 = 214.29
      expect(tax.vatExemptSales, 214.29);
      // 214.29 * 0.20 = 42.86
      expect(tax.discountAmount, 42.86);
      // 214.29 - 42.86 = 171.43
      expect(tax.netPayable, 171.43);
      expect(tax.vatableSales, 0.0);
      expect(tax.vatAmount, 0.0);
    });

    test('Student 10% discount computes accurately without VAT exemption', () {
      final tax = BirTaxBreakdown.compute(
        gross: 200.00,
        discountType: 'student',
      );

      // 10% discount on 200 = 20.00
      expect(tax.discountAmount, 20.00);
      // Net = 180.00
      expect(tax.netPayable, 180.00);
      // Vatable = 180 / 1.12 = 160.71
      expect(tax.vatableSales, 160.71);
      // VAT = 180 - 160.71 = 19.29
      expect(tax.vatAmount, 19.29);
      expect(tax.vatExemptSales, 0.0);
      expect(tax.grossSubtotal, 200.00);
    });

    test('Staff 15% discount computes accurately without VAT exemption', () {
      final tax = BirTaxBreakdown.compute(
        gross: 200.00,
        discountType: 'staff',
      );

      // 15% discount on 200 = 30.00
      expect(tax.discountAmount, 30.00);
      // Net = 170.00
      expect(tax.netPayable, 170.00);
      // Vatable = 170 / 1.12 = 151.79
      expect(tax.vatableSales, 151.79);
      // VAT = 170 - 151.79 = 18.21
      expect(tax.vatAmount, 18.21);
      expect(tax.vatExemptSales, 0.0);
      expect(tax.grossSubtotal, 200.00);
    });

    test('Zero or negative gross returns zero tax breakdown', () {
      final taxZero = BirTaxBreakdown.compute(
        gross: 0.0,
        discountType: 'none',
      );
      expect(taxZero.grossSubtotal, 0.0);
      expect(taxZero.netPayable, 0.0);

      final taxNegative = BirTaxBreakdown.compute(
        gross: -50.0,
        discountType: 'senior_citizen',
      );
      expect(taxNegative.grossSubtotal, 0.0);
      expect(taxNegative.netPayable, 0.0);
    });

    test('toJson serialization retains all tax fields', () {
      final tax = BirTaxBreakdown.compute(
        gross: 100.00,
        discountType: 'none',
      );
      final json = tax.toJson();
      expect(json['gross_subtotal'], 100.00);
      expect(json.containsKey('vatable_sales'), isTrue);
      expect(json.containsKey('vat_amount'), isTrue);
      expect(json.containsKey('net_payable'), isTrue);
    });
  });
}
