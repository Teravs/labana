import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/report_models.dart';
import 'report_date_helper.dart';

/// Generator dokumen PDF laporan penjualan Labana (Harian, Mingguan, Bulanan).
///
/// **Karakteristik**:
/// - Pure Dart service: tidak menggunakan UI Flutter, network call, font download runtime, atau timer.
/// - 100% Offline: Menggunakan font Type 1 Helvetica bawaan standar PDF.
/// - Single Source of Truth: Menerima [ReportData] langsung tanpa kueri SQLite ulang atau HppEngine.
/// - Multi-Page Ready: Menggunakan [pw.MultiPage] dengan tabel [pw.TableHelper.fromTextArray] yang mengulang header pada halaman baru.
class PdfReportGenerator {
  const PdfReportGenerator();

  /// Menghasilkan byte binary PDF dari [ReportData].
  Future<Uint8List> generateReportPdf(ReportData data) async {
    final pdf = pw.Document(
      title: 'Laporan Penjualan Labana - ${data.startDate}',
      author: 'Labana',
    );

    // Font standar built-in PDF (100% offline, 0 bytes download)
    final fontRegular = pw.Font.helvetica();
    final fontBold = pw.Font.helveticaBold();
    final fontOblique = pw.Font.helveticaOblique();

    // Palet warna cetak Labana
    const primaryEmerald = PdfColor.fromInt(0xFF146C5B);
    const secondaryGold = PdfColor.fromInt(0xFFD9A441);
    const textDark = PdfColor.fromInt(0xFF1E2925);
    const textMuted = PdfColor.fromInt(0xFF64748B);
    const tableHeaderBg = PdfColor.fromInt(0xFFF1F5F9);
    const borderColor = PdfColor.fromInt(0xFFE2E8F0);
    const boxBg = PdfColor.fromInt(0xFFF8FAFC);
    const successGreen = PdfColor.fromInt(0xFF2E7D32);
    const errorRed = PdfColor.fromInt(0xFFBA1A1A);

    final referenceDate = ReportDateHelper.parseDate(data.startDate);
    final periodLabel = ReportDateHelper.formatPeriodLabel(
      data.periodType,
      referenceDate,
    ).replaceAll('–', '-').replaceAll('—', '-').replaceAll('•', '-');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        header: (pw.Context context) {
          if (context.pageNumber > 1) {
            // Running header ringkas di halaman kedua dan seterusnya
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: borderColor, width: 0.5),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'LABANA - Laporan Penjualan (${data.periodType.label})',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: textMuted,
                    ),
                  ),
                  pw.Text(
                    periodLabel,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 8,
                      color: textMuted,
                    ),
                  ),
                ],
              ),
            );
          }

          // Header utama halaman pertama
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: primaryEmerald, width: 2),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'LABANA',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 20,
                        color: primaryEmerald,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Kelola Modal, Pahami Laba.',
                      style: pw.TextStyle(
                        font: fontOblique,
                        fontSize: 9,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'LAPORAN PENJUALAN',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: 12,
                        color: textDark,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Periode: $periodLabel',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10,
                        color: primaryEmerald,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Labana - Kelola Modal, Pahami Laba.',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: textMuted,
                  ),
                ),
                pw.Text(
                  'Halaman ${context.pageNumber} dari ${context.pagesCount}',
                  style: pw.TextStyle(
                    font: fontRegular,
                    fontSize: 8,
                    color: textMuted,
                  ),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            // 1. Ringkasan Finansial
            _buildFinancialSummary(
              data.summary,
              fontRegular,
              fontBold,
              primaryEmerald,
              secondaryGold,
              textDark,
              textMuted,
              boxBg,
              borderColor,
              successGreen,
              errorRed,
            ),
            pw.SizedBox(height: 14),

            // 2. Performa Produk Utama (Produk Terlaris & Laba Tertinggi)
            _buildTopPerformers(
              data,
              fontRegular,
              fontBold,
              primaryEmerald,
              secondaryGold,
              textDark,
              textMuted,
              boxBg,
              borderColor,
              successGreen,
            ),
            pw.SizedBox(height: 14),

            // 3. Catatan jika periode kosong
            if (data.isEmpty) ...[
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: boxBg,
                  borderRadius: const pw.BorderRadius.all(
                    pw.Radius.circular(6),
                  ),
                  border: pw.Border.all(color: borderColor, width: 0.8),
                ),
                child: pw.Center(
                  child: pw.Text(
                    'Belum ada transaksi pada periode ini.',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10,
                      color: textMuted,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(height: 14),
            ],

            // 4. Breakdown Performa Per Produk
            if (data.products.isNotEmpty) ...[
              _buildSectionTitle('PERFORMA PER PRODUK', fontBold, textDark),
              pw.SizedBox(height: 6),
              _buildProductTable(
                data.products,
                fontRegular,
                fontBold,
                tableHeaderBg,
                borderColor,
                textDark,
                successGreen,
                errorRed,
              ),
              pw.SizedBox(height: 14),
            ],

            // 5. Breakdown Harian (khusus Mingguan & Bulanan)
            if (data.periodType != ReportPeriodType.daily &&
                data.dailyBreakdown.isNotEmpty) ...[
              _buildSectionTitle(
                'BREAKDOWN HARIAN (${data.dailyBreakdown.length} HARI)',
                fontBold,
                textDark,
              ),
              pw.SizedBox(height: 6),
              _buildDailyBreakdownTable(
                data.dailyBreakdown,
                fontRegular,
                fontBold,
                tableHeaderBg,
                borderColor,
                textDark,
                textMuted,
                successGreen,
                errorRed,
              ),
              pw.SizedBox(height: 14),
            ],

            // 6. Ringkasan Metode Pembayaran
            if (data.paymentMethods.isNotEmpty) ...[
              _buildSectionTitle('METODE PEMBAYARAN', fontBold, textDark),
              pw.SizedBox(height: 6),
              _buildPaymentMethodTable(
                data.paymentMethods,
                fontRegular,
                fontBold,
                tableHeaderBg,
                borderColor,
                textDark,
              ),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildSectionTitle(String title, pw.Font fontBold, PdfColor color) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        font: fontBold,
        fontSize: 10,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  pw.Widget _buildFinancialSummary(
    ReportSummary summary,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor primaryEmerald,
    PdfColor secondaryGold,
    PdfColor textDark,
    PdfColor textMuted,
    PdfColor boxBg,
    PdfColor borderColor,
    PdfColor successGreen,
    PdfColor errorRed,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: boxBg,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'RINGKASAN FINANSIAL',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10,
              color: primaryEmerald,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              // Kolom 1
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildMetricRow(
                      'Omzet',
                      summary.formattedTotalOmzet,
                      fontRegular,
                      fontBold,
                      textMuted,
                      textDark,
                    ),
                    pw.SizedBox(height: 4),
                    _buildMetricRow(
                      'Modal / HPP',
                      summary.formattedTotalHpp,
                      fontRegular,
                      fontBold,
                      textMuted,
                      textDark,
                    ),
                    pw.SizedBox(height: 4),
                    _buildMetricRow(
                      'Estimasi Laba',
                      summary.formattedTotalProfit,
                      fontRegular,
                      fontBold,
                      textMuted,
                      summary.totalProfit >= 0 ? successGreen : errorRed,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              // Kolom 2
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildMetricRow(
                      'Margin Laba',
                      summary.formattedProfitMargin,
                      fontRegular,
                      fontBold,
                      textMuted,
                      textDark,
                    ),
                    pw.SizedBox(height: 4),
                    _buildMetricRow(
                      'Jumlah Transaksi',
                      '${summary.transactionCount}',
                      fontRegular,
                      fontBold,
                      textMuted,
                      textDark,
                    ),
                    pw.SizedBox(height: 4),
                    _buildMetricRow(
                      'Produk Terjual',
                      '${summary.formattedProductsSold} porsi',
                      fontRegular,
                      fontBold,
                      textMuted,
                      textDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricRow(
    String label,
    String value,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor labelColor,
    PdfColor valueColor,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: fontRegular,
            fontSize: 9,
            color: labelColor,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(font: fontBold, fontSize: 9, color: valueColor),
        ),
      ],
    );
  }

  pw.Widget _buildTopPerformers(
    ReportData data,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor primaryEmerald,
    PdfColor secondaryGold,
    PdfColor textDark,
    PdfColor textMuted,
    PdfColor boxBg,
    PdfColor borderColor,
    PdfColor successGreen,
  ) {
    final topSelling = data.topSelling;
    final highestProfit = data.highestProfit;

    final topSellingName = topSelling != null
        ? '${topSelling.productName} (${topSelling.formattedQuantity} terjual)'
        : 'Belum ada penjualan';
    final highestProfitName = highestProfit != null
        ? '${highestProfit.productName} (${highestProfit.formattedProfit})'
        : 'Belum ada penjualan';

    return pw.Row(
      children: [
        // Card Produk Terlaris
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: boxBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PRODUK TERLARIS',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: primaryEmerald,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  topSellingName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        // Card Laba Tertinggi
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: boxBg,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
              border: pw.Border.all(color: borderColor, width: 0.8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'LABA TERTINGGI',
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 8,
                    color: secondaryGold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  highestProfitName,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: 9,
                    color: textDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildProductTable(
    List<ReportProductStat> products,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor headerBg,
    PdfColor borderColor,
    PdfColor textDark,
    PdfColor successGreen,
    PdfColor errorRed,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: textDark),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      headerHeight: 22,
      cellHeight: 20,
      cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8, color: textDark),
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.centerLeft,
        2: pw.Alignment.centerRight,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: [
        'No',
        'Nama Produk',
        'Terjual',
        'Omzet',
        'Modal / HPP',
        'Estimasi Laba',
      ],
      data: List<List<String>>.generate(products.length, (index) {
        final p = products[index];
        return [
          '${index + 1}',
          p.productName,
          p.formattedQuantity,
          p.formattedOmzet,
          p.formattedHpp,
          p.formattedProfit,
        ];
      }),
    );
  }

  pw.Widget _buildDailyBreakdownTable(
    List<DailyReportStat> dailyList,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor headerBg,
    PdfColor borderColor,
    PdfColor textDark,
    PdfColor textMuted,
    PdfColor successGreen,
    PdfColor errorRed,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: textDark),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      headerHeight: 22,
      cellHeight: 18,
      cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8, color: textDark),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.center,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
        5: pw.Alignment.centerRight,
      },
      headers: ['Tanggal', 'Transaksi', 'Terjual', 'Omzet', 'HPP', 'Laba'],
      data: List<List<String>>.generate(dailyList.length, (index) {
        final d = dailyList[index];
        return [
          d.formattedDateDisplay,
          '${d.transactionCount}',
          d.formattedProductsSold,
          d.formattedOmzet,
          d.formattedHpp,
          d.formattedProfit,
        ];
      }),
    );
  }

  pw.Widget _buildPaymentMethodTable(
    List<PaymentMethodStat> methods,
    pw.Font fontRegular,
    pw.Font fontBold,
    PdfColor headerBg,
    PdfColor borderColor,
    PdfColor textDark,
  ) {
    return pw.TableHelper.fromTextArray(
      border: pw.TableBorder.all(color: borderColor, width: 0.5),
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 8.5, color: textDark),
      headerDecoration: pw.BoxDecoration(color: headerBg),
      headerHeight: 22,
      cellHeight: 20,
      cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8, color: textDark),
      cellAlignments: {
        0: pw.Alignment.centerLeft,
        1: pw.Alignment.center,
        2: pw.Alignment.centerRight,
      },
      headers: ['Metode Pembayaran', 'Jumlah Transaksi', 'Total Omzet'],
      data: List<List<String>>.generate(methods.length, (index) {
        final m = methods[index];
        return [
          m.paymentMethodLabel,
          '${m.transactionCount} transaksi',
          m.formattedTotalAmount,
        ];
      }),
    );
  }
}
