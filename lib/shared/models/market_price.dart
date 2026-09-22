/// Mandi (APMC) market price model — mirrors backend/app/schemas.py
/// MarketPriceOut. Real Agmarknet data via data.gov.in, see
/// backend/app/connectors/agmarknet.py.
class MarketPrice {
  final String? commodity;
  final String? variety;
  final String? market;
  final String? district;
  final String? state;
  final double? minPrice;
  final double? maxPrice;
  final double? modalPrice;
  final String? arrivalDate;

  const MarketPrice({
    this.commodity,
    this.variety,
    this.market,
    this.district,
    this.state,
    this.minPrice,
    this.maxPrice,
    this.modalPrice,
    this.arrivalDate,
  });

  factory MarketPrice.fromJson(Map<String, dynamic> json) {
    return MarketPrice(
      commodity: json['commodity'] as String?,
      variety: json['variety'] as String?,
      market: json['market'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      modalPrice: (json['modal_price'] as num?)?.toDouble(),
      arrivalDate: json['arrival_date'] as String?,
    );
  }

  /// "Market, District" with whichever parts are actually present.
  String get location =>
      [market, district].where((p) => p != null && p.isNotEmpty).join(', ');
}
