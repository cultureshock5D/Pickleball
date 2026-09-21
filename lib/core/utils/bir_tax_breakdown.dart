/// Philippine BIR EOPT & Statutory Compliance Tax Breakdown Model
/// Implements RA 9994 (Senior Citizens Act) & RA 10754 (PWD Act) calculations.
class BirTaxBreakdown {
  final double grossSubtotal;
  final double vatableSales;
  final double vatAmount;
  final double vatExemptSales;
  final double discountAmount;
  final double netPayable;

  const BirTaxBreakdown({
    required this.grossSubtotal,
    required this.vatableSales,
    required this.vatAmount,
    required this.vatExemptSales,
    required this.discountAmount,
    required this.netPayable,
  });

  static const BirTaxBreakdown zero = BirTaxBreakdown(
    grossSubtotal: 0.0,
    vatableSales: 0.0,
    vatAmount: 0.0,
    vatExemptSales: 0.0,
    discountAmount: 0.0,
    netPayable: 0.0,
  );

  factory BirTaxBreakdown.compute({
    required double gross,
    required String discountType, // 'none', 'senior_citizen', 'pwd'
  }) {
    if (gross <= 0.0) {
      return BirTaxBreakdown.zero;
    }

    double round2(double val) => (val * 100).roundToDouble() / 100;

    if (discountType == 'senior_citizen' || discountType == 'pwd') {
      // 1. Remove 12% VAT to get VAT-Exempt Base
      final vatExemptBase = round2(gross / 1.12);
      // 2. Compute 20% Statutory Discount on Net Base
      final discount = round2(vatExemptBase * 0.20);
      // 3. Final Net Payable
      final net = round2(vatExemptBase - discount);

      return BirTaxBreakdown(
        grossSubtotal: round2(gross),
        vatableSales: 0.0,
        vatAmount: 0.0,
        vatExemptSales: vatExemptBase,
        discountAmount: discount,
        netPayable: net,
      );
    } else {
      // Regular 12% VAT Registered Sale
      final vatable = round2(gross / 1.12);
      final vat = round2(gross - vatable);

      return BirTaxBreakdown(
        grossSubtotal: round2(gross),
        vatableSales: vatable,
        vatAmount: vat,
        vatExemptSales: 0.0,
        discountAmount: 0.0,
        netPayable: round2(gross),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'gross_subtotal': grossSubtotal,
      'vatable_sales': vatableSales,
      'vat_amount': vatAmount,
      'vat_exempt_sales': vatExemptSales,
      'discount_amount': discountAmount,
      'net_payable': netPayable,
    };
  }
}
