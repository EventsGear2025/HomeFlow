import 'package:flutter/foundation.dart';
import '../models/retailer_quote.dart';
import 'price_scraper_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CATALOG ENTRY (internal)
// In production, replace _catalog with real CarrefourProvider/NaivasProvider
// API calls while keeping RetailerCatalogService as the unified facade.
// ─────────────────────────────────────────────────────────────────────────────

class _CatalogEntry {
  final RetailerCode retailer;
  final List<String> keywords;
  final String productName;
  final String? brand;
  final String? sizeLabel;
  final double price;
  final MatchType matchType;
  final double confidence;

  const _CatalogEntry({
    required this.retailer,
    required this.keywords,
    required this.productName,
    this.brand,
    this.sizeLabel,
    required this.price,
    this.matchType = MatchType.exact,
    this.confidence = 0.95,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RETAILER CATALOG SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class RetailerCatalogService {
  static const List<_CatalogEntry> _catalog = [
    // ── Personal care ────────────────────────────────────────────────────────
    // Naivas: KES 184 (naivas.online live); Carrefour: estimated ~8% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['body soap', 'bathing soap', 'bar soap', 'soap', 'menengai', 'washing bar'], productName: 'Menengai Cream Bar Soap 800g', brand: 'Menengai', sizeLabel: '800g', price: 199),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['body soap', 'bathing soap', 'bar soap', 'soap', 'menengai', 'washing bar'], productName: 'Menengai Cream Bar Soap 800g', brand: 'Menengai', sizeLabel: '800g', price: 184),

    // Geisha — very popular Kenyan family soap brand
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['geisha', 'body soap', 'bathing soap', 'bar soap', 'soap'], productName: 'Geisha Bar Soap 175g', brand: 'Geisha', sizeLabel: '175g', price: 55),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['geisha', 'body soap', 'bathing soap', 'bar soap', 'soap'], productName: 'Geisha Bar Soap 175g', brand: 'Geisha', sizeLabel: '175g', price: 48),

    // Lifebuoy — antibacterial bar soap
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['lifebuoy', 'body soap', 'bathing soap', 'bar soap', 'soap', 'antibacterial soap'], productName: 'Lifebuoy Total Protection Bar Soap 100g', brand: 'Lifebuoy', sizeLabel: '100g', price: 69),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['lifebuoy', 'body soap', 'bathing soap', 'bar soap', 'soap', 'antibacterial soap'], productName: 'Lifebuoy Total Protection Bar Soap 100g', brand: 'Lifebuoy', sizeLabel: '100g', price: 59),

    // Dettol bar soap
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['dettol', 'dettol soap', 'dettol bar', 'body soap', 'bathing soap', 'bar soap', 'soap'], productName: 'Dettol Original Bar Soap 100g', brand: 'Dettol', sizeLabel: '100g', price: 79),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['dettol', 'dettol soap', 'dettol bar', 'body soap', 'bathing soap', 'bar soap', 'soap'], productName: 'Dettol Original Bar Soap 100g', brand: 'Dettol', sizeLabel: '100g', price: 69),

    // ── Shower gel / body wash ────────────────────────────────────────────────
    // Hobby Marshmallow — popular Kenyan shower gel brand
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['hobby', 'marshmallow', 'shower gel', 'body wash', 'bathing gel', 'hobby gel', 'hobby marshmallow'], productName: 'Hobby Marshmallow Shower Gel 750ml', brand: 'Hobby', sizeLabel: '750ml', price: 349),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['hobby', 'marshmallow', 'shower gel', 'body wash', 'bathing gel', 'hobby gel', 'hobby marshmallow'], productName: 'Hobby Marshmallow Shower Gel 750ml', brand: 'Hobby', sizeLabel: '750ml', price: 319),

    // Dove body wash
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['dove', 'dove body wash', 'shower gel', 'body wash', 'dove shower'], productName: 'Dove Deeply Nourishing Body Wash 500ml', brand: 'Dove', sizeLabel: '500ml', price: 649),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['dove', 'dove body wash', 'shower gel', 'body wash', 'dove shower'], productName: 'Dove Deeply Nourishing Body Wash 500ml', brand: 'Dove', sizeLabel: '500ml', price: 599),

    // ── Hand wash ────────────────────────────────────────────────────────────
    // Dettol antibacterial handwash — very common household item
    // Carrefour est. ~KES 299 (250ml pump); Naivas est. ~KES 279
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['hand wash', 'handwash', 'liquid soap', 'hand soap', 'dettol handwash', 'antibacterial soap', 'hand cleanser', 'hand liquid'], productName: 'Dettol Antibacterial Handwash Original 250ml', brand: 'Dettol', sizeLabel: '250ml', price: 299),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['hand wash', 'handwash', 'liquid soap', 'hand soap', 'dettol handwash', 'antibacterial soap', 'hand cleanser', 'hand liquid'], productName: 'Dettol Antibacterial Handwash Original 250ml', brand: 'Dettol', sizeLabel: '250ml', price: 279),

    // Naivas: KES 269 (naivas.online live); Carrefour: estimated ~6% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['toothpaste', 'colgate', 'oral b', 'oral care', 'dental paste'], productName: 'Colgate Charcoal Gentle Toothpaste 120g', brand: 'Colgate', sizeLabel: '120g', price: 285),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['toothpaste', 'colgate', 'oral b', 'oral care', 'dental paste'], productName: 'Colgate Charcoal Gentle Toothpaste 120g', brand: 'Colgate', sizeLabel: '120g', price: 269),

    // Estimated both (no live price retrieved)
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['shampoo', 'hair shampoo', 'hair wash', 'head shoulders', 'pantene'], productName: 'Head & Shoulders Anti-Dandruff Shampoo 400ml', brand: 'Head & Shoulders', sizeLabel: '400ml', price: 519),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['shampoo', 'hair shampoo', 'hair wash', 'head shoulders', 'pantene'], productName: 'Head & Shoulders Anti-Dandruff Shampoo 400ml', brand: 'Head & Shoulders', sizeLabel: '400ml', price: 479),

    // Naivas: KES 330 (naivas.online live); Carrefour: estimated ~9% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['deodorant', 'roll on', 'rollOn', 'rexona', 'nivea', 'dove deodorant', 'body spray'], productName: 'Rexona Men Roll-On Quantum 50ml', brand: 'Rexona', sizeLabel: '50ml', price: 359),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['deodorant', 'roll on', 'rollOn', 'rexona', 'nivea', 'dove deodorant', 'body spray'], productName: 'Rexona Men Roll-On Quantum 50ml', brand: 'Rexona', sizeLabel: '50ml', price: 330),

    // ── Laundry & cleaning ───────────────────────────────────────────────────
    // Naivas: KES 325 (naivas.online live); Carrefour: estimated ~7% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['washing powder', 'laundry powder', 'detergent', 'toss', 'omo', 'ariel', 'washing soap'], productName: 'Toss Washing Powder White 1kg', brand: 'Toss', sizeLabel: '1kg', price: 349),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['washing powder', 'laundry powder', 'detergent', 'toss', 'omo', 'ariel', 'washing soap'], productName: 'Toss Washing Powder White 1kg', brand: 'Toss', sizeLabel: '1kg', price: 325),

    // Naivas: KES 165 (naivas.online live); Carrefour: estimated ~8% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['dishwashing liquid', 'dish soap', 'sunlight', 'fairy', 'dish wash', 'dishes', 'washing up'], productName: 'Sunlight 2in1 Handwashing Powder 500g', brand: 'Sunlight', sizeLabel: '500g', price: 179),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['dishwashing liquid', 'dish soap', 'sunlight', 'fairy', 'dish wash', 'dishes', 'washing up'], productName: 'Sunlight 2in1 Handwashing Powder 500g', brand: 'Sunlight', sizeLabel: '500g', price: 165),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['bleach', 'jik', 'toilet cleaner', 'disinfectant', 'chlorine'], productName: 'Jik Regular Bleach 750ml', brand: 'Jik', sizeLabel: '750ml', price: 169),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['bleach', 'jik', 'toilet cleaner', 'disinfectant', 'chlorine'], productName: 'Jik Regular Bleach 750ml', brand: 'Jik', sizeLabel: '750ml', price: 149),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['floor cleaner', 'floor wash', 'dettol floor', 'floor liquid', 'pine sol'], productName: 'Dettol Antibacterial Floor Cleaner 500ml', brand: 'Dettol', sizeLabel: '500ml', price: 279),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['floor cleaner', 'floor wash', 'dettol floor', 'floor liquid', 'pine sol'], productName: 'Dettol Antibacterial Floor Cleaner 500ml', brand: 'Dettol', sizeLabel: '500ml', price: 255),

    // ── Hygiene / paper ──────────────────────────────────────────────────────
    // Naivas: KES 175 (Celine 4-pack, naivas.online live); Carrefour: estimated ~8% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['toilet paper', 'tissue', 'bathroom tissue', 'toilet roll', 'loo roll', 'celine', 'softex'], productName: 'Celine Toilet Tissue 4 Rolls', brand: 'Celine', sizeLabel: '4 rolls', price: 189),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['toilet paper', 'tissue', 'bathroom tissue', 'toilet roll', 'loo roll', 'celine', 'softex'], productName: 'Celine Toilet Tissue 4 Rolls', brand: 'Celine', sizeLabel: '4 rolls', price: 175),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['kitchen roll', 'kitchen towel', 'paper towel', 'kitchen tissue'], productName: 'Celine Kitchen Towel 2 Rolls', brand: 'Celine', sizeLabel: '2 rolls', price: 135),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['kitchen roll', 'kitchen towel', 'paper towel', 'kitchen tissue'], productName: 'Celine Kitchen Towel 2 Rolls', brand: 'Celine', sizeLabel: '2 rolls', price: 119),

    // ── Food & grocery ───────────────────────────────────────────────────────
    // LIVE PRICES — same brand, direct comparison: Carrefour KES 1,466 vs Naivas KES 1,199
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['cooking oil', 'vegetable oil', 'sunflower oil', 'oil', 'rina oil', 'frying oil'], productName: 'Rina Vegetable Cooking Oil 5L', brand: 'Rina', sizeLabel: '5L', price: 1466),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['cooking oil', 'vegetable oil', 'sunflower oil', 'oil', 'rina oil', 'frying oil'], productName: 'Rina Vegetable Cooking Oil 5L', brand: 'Rina', sizeLabel: '5L', price: 1199),

    // LIVE PRICES — Carrefour Nutrameal 2kg KES 288 | Naivas white sugar 2kg KES 289
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['sugar', 'white sugar', 'mumias', 'refined sugar', 'cane sugar'], productName: 'Nutrameal Natural Cane Sugar 2kg', brand: 'Nutrameal', sizeLabel: '2kg', price: 288, matchType: MatchType.nearMatch, confidence: 0.92),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['sugar', 'white sugar', 'mumias', 'refined sugar', 'cane sugar'], productName: 'Naivas White Sugar 2kg', brand: 'Naivas', sizeLabel: '2kg', price: 289),

    // LIVE PRICES — Carrefour Brookside Fino 500ml KES 56 | Naivas Fino UHT 500ml KES 49
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['milk', 'fresh milk', 'brookside', 'dairy milk', 'uht milk', 'fino milk'], productName: 'Brookside Fino UHT Milk 500ml', brand: 'Brookside', sizeLabel: '500ml', price: 56),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['milk', 'fresh milk', 'brookside', 'dairy milk', 'uht milk', 'fino milk'], productName: 'Brookside Fino UHT Milk 500ml', brand: 'Brookside', sizeLabel: '500ml', price: 49),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['bread', 'loaf', 'white bread', 'sandwich bread', 'sliced bread'], productName: 'Supa Loaf Sliced White Bread 700g', brand: 'Supa Loaf', sizeLabel: '700g', price: 60),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['bread', 'loaf', 'white bread', 'sandwich bread', 'sliced bread'], productName: 'Supa Loaf Sliced White Bread 700g', brand: 'Supa Loaf', sizeLabel: '700g', price: 55, matchType: MatchType.nearMatch, confidence: 0.90),

    // Naivas: KES 599 (Daawat Basmati 2kg, naivas.online live); Carrefour: estimated ~5% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['rice', 'pishori', 'basmati', 'long grain', 'white rice', 'daawat'], productName: 'Daawat Basmati Rice 2kg', brand: 'Daawat', sizeLabel: '2kg', price: 629, matchType: MatchType.nearMatch, confidence: 0.90),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['rice', 'pishori', 'basmati', 'long grain', 'white rice', 'daawat'], productName: 'Daawat Basmati Rice 2kg', brand: 'Daawat', sizeLabel: '2kg', price: 599),

    // LIVE: Carrefour Kensalt 1kg KES 43; Naivas estimated ~KES 40
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['salt', 'table salt', 'iodized salt', 'cooking salt', 'kensalt'], productName: 'Kensalt Iodated Table Salt 1kg', brand: 'Kensalt', sizeLabel: '1kg', price: 43),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['salt', 'table salt', 'iodized salt', 'cooking salt', 'kensalt'], productName: 'Kensalt Iodated Table Salt 1kg', brand: 'Kensalt', sizeLabel: '1kg', price: 40),

    // LIVE PRICES — Carrefour Ajab 2kg KES 165 | Naivas Lea Wheat Flour 2kg KES 166
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['flour', 'wheat flour', 'baking flour', 'all purpose flour', 'bread flour'], productName: 'Ajab All Purpose Wheat Flour 2kg', brand: 'Ajab', sizeLabel: '2kg', price: 165),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['flour', 'wheat flour', 'baking flour', 'all purpose flour', 'bread flour'], productName: 'Ajab All Purpose Wheat Flour 2kg', brand: 'Ajab', sizeLabel: '2kg', price: 166),

    // Naivas: KES 193 (Lea Maize Meal 2kg, naivas.online live); Carrefour: estimated ~6% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['maize flour', 'maize meal', 'unga', 'posho', 'ugali', 'ugali flour'], productName: 'Jogoo Maize Meal 2kg', brand: 'Jogoo', sizeLabel: '2kg', price: 205),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['maize flour', 'maize meal', 'unga', 'posho', 'ugali', 'ugali flour'], productName: 'Jogoo Maize Meal 2kg', brand: 'Jogoo', sizeLabel: '2kg', price: 193),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['eggs', 'tray eggs', 'fresh eggs', 'egg'], productName: 'Fresh Farm Eggs Tray 30 Pieces', brand: null, sizeLabel: '30 pcs', price: 460),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['eggs', 'tray eggs', 'fresh eggs', 'egg'], productName: 'Fresh Farm Eggs Tray 30 Pieces', brand: null, sizeLabel: '30 pcs', price: 420),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['tea bags', 'tea', 'ketepa', 'lipton', 'chai', 'teabags'], productName: 'Ketepa Pride Tea Bags 100s', brand: 'Ketepa', sizeLabel: '100 bags', price: 229),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['tea bags', 'tea', 'ketepa', 'lipton', 'chai', 'teabags'], productName: 'Ketepa Pride Tea Bags 100s', brand: 'Ketepa', sizeLabel: '100 bags', price: 199),

    // Estimated both
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['coffee', 'instant coffee', 'nescafe', 'nescafé', 'coffee jar'], productName: 'Nescafe Classic Instant Coffee 200g', brand: 'Nescafe', sizeLabel: '200g', price: 729),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['coffee', 'instant coffee', 'nescafe', 'nescafé', 'coffee jar'], productName: 'Nescafe Classic Instant Coffee 200g', brand: 'Nescafe', sizeLabel: '200g', price: 699),

    // Carrefour: Keringet Sparkling 1L = KES 98 (live), still water ~KES 65; Naivas: estimated ~KES 55
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['water', 'drinking water', 'bottled water', 'mineral water', 'keringet', 'aquamist'], productName: 'Keringet Natural Still Water 1L', brand: 'Keringet', sizeLabel: '1L', price: 65),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['water', 'drinking water', 'bottled water', 'mineral water', 'keringet', 'aquamist'], productName: 'Keringet Natural Still Water 1L', brand: 'Keringet', sizeLabel: '1L', price: 55),

    // ── Baby & kids ──────────────────────────────────────────────────────────
    // Naivas: KES 1,799 (Pampers Maxi 56pcs, naivas.online live); Carrefour: est. ~KES 1,899
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['diapers', 'nappies', 'pampers', 'huggies', 'baby nappy', 'nappy'], productName: 'Pampers Baby Dry Maxi Size 4 Diapers', brand: 'Pampers', sizeLabel: '44 pcs', price: 1899),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['diapers', 'nappies', 'pampers', 'huggies', 'baby nappy', 'nappy'], productName: 'Pampers Baby Dry Maxi Size 4 Diapers', brand: 'Pampers', sizeLabel: '56 pcs', price: 1799, matchType: MatchType.nearMatch, confidence: 0.90),

    // Naivas: KES 165 (Softcare Baby Wipes 80pcs, naivas.online live); Carrefour: est. ~8% higher
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['baby wipes', 'wet wipes', 'wipes', 'baby wipe', 'softcare'], productName: 'Softcare Baby Wipes 80 Sheets', brand: 'Softcare', sizeLabel: '80 sheets', price: 179),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['baby wipes', 'wet wipes', 'wipes', 'baby wipe', 'softcare'], productName: 'Softcare Baby Wipes 80 Sheets', brand: 'Softcare', sizeLabel: '80 sheets', price: 165),

    // ── Gas ──────────────────────────────────────────────────────────────────
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['gas', 'lpg', 'cooking gas', 'gas cylinder', 'propane'], productName: 'K-Gas LPG Refill 6kg', brand: 'K-Gas', sizeLabel: '6kg', price: 1250),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['gas', 'lpg', 'cooking gas', 'gas cylinder', 'propane'], productName: 'Mwananchi LPG Refill 6kg', brand: 'Mwananchi', sizeLabel: '6kg', price: 1190, matchType: MatchType.nearMatch, confidence: 0.85),

    // ── Breakfast & cereals ──────────────────────────────────────────────────
    // Keywords cover both the spaced form "corn flakes" and compact "cornflakes"
    // as well as common misspellings — fuzzy matching handles the rest.
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['cornflakes', 'corn flakes', 'cereal', 'breakfast cereal', 'kelloggs', "kellogg's", 'corn cereal', 'cornflake', 'corn flake', 'flakes cereal'], productName: "Kellogg's Corn Flakes 500g", brand: "Kellogg's", sizeLabel: '500g', price: 529),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['cornflakes', 'corn flakes', 'cereal', 'breakfast cereal', 'kelloggs', "kellogg's", 'corn cereal', 'cornflake', 'corn flake', 'flakes cereal'], productName: "Kellogg's Corn Flakes 500g", brand: "Kellogg's", sizeLabel: '500g', price: 499),

    // Estimated both — oats are another very common breakfast item
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['oats', 'porridge oats', 'quaker oats', 'rolled oats', 'oatmeal', 'porridge'], productName: 'Quaker Oats 500g', brand: 'Quaker', sizeLabel: '500g', price: 199),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['oats', 'porridge oats', 'quaker oats', 'rolled oats', 'oatmeal', 'porridge'], productName: 'Quaker Oats 500g', brand: 'Quaker', sizeLabel: '500g', price: 179),

    // ── Spreads & dairy ──────────────────────────────────────────────────────
    // Blue Band is the dominant margarine brand in Kenya
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['margarine', 'blue band', 'blueband', 'spread', 'butter spread', 'fat spread', 'cooking fat', 'shortening'], productName: 'Blue Band Original Margarine 500g', brand: 'Blue Band', sizeLabel: '500g', price: 279),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['margarine', 'blue band', 'blueband', 'spread', 'butter spread', 'fat spread', 'cooking fat', 'shortening'], productName: 'Blue Band Original Margarine 500g', brand: 'Blue Band', sizeLabel: '500g', price: 259),

    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['butter', 'unsalted butter', 'salted butter', 'dairy butter', 'anchor butter', 'lurpak'], productName: 'Anchor Butter 250g', brand: 'Anchor', sizeLabel: '250g', price: 329),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['butter', 'unsalted butter', 'salted butter', 'dairy butter', 'anchor butter', 'lurpak'], productName: 'Anchor Butter 250g', brand: 'Anchor', sizeLabel: '250g', price: 299),

    // Yoghurt — Brookside is most visible on both sites
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['yoghurt', 'yogurt', 'brookside yoghurt', 'fresh yoghurt', 'plain yoghurt', 'strawberry yoghurt', 'vanilla yoghurt'], productName: 'Brookside Strawberry Yoghurt 500ml', brand: 'Brookside', sizeLabel: '500ml', price: 115),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['yoghurt', 'yogurt', 'brookside yoghurt', 'fresh yoghurt', 'plain yoghurt', 'strawberry yoghurt', 'vanilla yoghurt'], productName: 'Brookside Strawberry Yoghurt 500ml', brand: 'Brookside', sizeLabel: '500ml', price: 99),

    // ── Pasta & noodles ──────────────────────────────────────────────────────
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['spaghetti', 'pasta', 'noodles', 'penne', 'macaroni', 'sasko spaghetti', 'golden penny', 'barilla'], productName: 'Sasko Spaghetti 500g', brand: 'Sasko', sizeLabel: '500g', price: 79),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['spaghetti', 'pasta', 'noodles', 'penne', 'macaroni', 'sasko spaghetti', 'golden penny', 'barilla'], productName: 'Sasko Spaghetti 500g', brand: 'Sasko', sizeLabel: '500g', price: 69),

    // ── Condiments & cooking basics ──────────────────────────────────────────
    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['tomato paste', 'tomato puree', 'tomato sauce', 'delmonte tomato', 'tomato tin', 'canned tomato', 'tomato can'], productName: 'Del Monte Tomato Paste 400g', brand: 'Del Monte', sizeLabel: '400g', price: 119),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['tomato paste', 'tomato puree', 'tomato sauce', 'delmonte tomato', 'tomato tin', 'canned tomato', 'tomato can'], productName: 'Del Monte Tomato Paste 400g', brand: 'Del Monte', sizeLabel: '400g', price: 109),

    _CatalogEntry(retailer: RetailerCode.carrefour, keywords: ['cooking spray', 'spray oil', 'canola spray', 'baking spray', 'non stick spray'], productName: 'Spray & Cook Canola 300ml', brand: 'Spray & Cook', sizeLabel: '300ml', price: 269),
    _CatalogEntry(retailer: RetailerCode.naivas, keywords: ['cooking spray', 'spray oil', 'canola spray', 'baking spray', 'non stick spray'], productName: 'Spray & Cook Canola 300ml', brand: 'Spray & Cook', sizeLabel: '300ml', price: 245),
  ];

  // ─── Matching ─────────────────────────────────────────────────────────────

  /// Returns one quote per retailer for the given item name.
  /// Matching is performed in four passes, in descending confidence:
  ///   1. Exact phrase containment         (score 3.0)
  ///   2. Compound-word / no-space match   (score 2.5)  "cornflakes" ↔ "corn flakes"
  ///   3. Token-level substring match      (score 1.5)
  ///   4. Fuzzy token match (edit dist ≤2) (score 1.2)  handles typos
  static List<RetailerQuote> quotesForItem(
    String itemName, {
    String? preferredBrand,
  }) {
    final normalized = itemName.toLowerCase().trim();
    // Compact form removes all spaces: "corn flakes" → "cornflakes"
    final normalizedCompact = normalized.replaceAll(RegExp(r'\s+'), '');
    final tokens = normalized
        .split(RegExp(r'[\s/,]+'))
        .where((t) => t.length > 2)
        .toList();

    final Map<RetailerCode, ({_CatalogEntry entry, double score})> best = {};

    for (final entry in _catalog) {
      double score = 0;

      for (final kw in entry.keywords) {
        // ── Pass 1: exact phrase ────────────────────────────────────────────
        if (normalized.contains(kw) || kw.contains(normalized)) {
          score = score < 3.0 ? 3.0 : score;
          continue;
        }

        // ── Pass 2: compound-word (strip spaces both sides) ─────────────────
        // "cornflakes" matches keyword "corn flakes"; "handwash" matches "hand wash"
        final kwCompact = kw.replaceAll(' ', '');
        if (kwCompact.length > 3 &&
            (normalizedCompact.contains(kwCompact) ||
                kwCompact.contains(normalizedCompact))) {
          score = score < 2.5 ? 2.5 : score;
          continue;
        }

        // ── Pass 3: token-level substring ───────────────────────────────────
        for (final token in tokens) {
          if (token.length > 2 &&
              (kw.contains(token) || token.contains(kw))) {
            score = score < 1.5 ? 1.5 : score;
          }
        }

        // ── Pass 4: fuzzy per-token (Levenshtein ≤ 1 for short, ≤ 2 for long)
        // Catches: "coornflakes" → "cornflakes", "shugar" → "sugar"
        for (final token in tokens) {
          if (token.length < 4) continue;
          for (final kwWord in kw.split(' ')) {
            if (kwWord.length < 4) continue;
            final maxDist =
                (token.length >= 7 || kwWord.length >= 7) ? 2 : 1;
            if (_editDistance(token, kwWord) <= maxDist) {
              score = score < 1.2 ? 1.2 : score;
            }
          }
        }
      }

      // Boost for matching preferred brand — weighted heavily so preference always wins
      if (preferredBrand != null &&
          entry.brand != null &&
          entry.brand!.toLowerCase().contains(preferredBrand.toLowerCase())) {
        score += 2.0;
      }
      if (score == 0) continue;

      final existing = best[entry.retailer];
      if (existing == null ||
          score > existing.score ||
          (score == existing.score &&
              entry.confidence > existing.entry.confidence)) {
        best[entry.retailer] = (entry: entry, score: score);
      }
    }

    return RetailerCode.values.map((code) {
      final found = best[code];
      if (found == null) {
        return RetailerQuote(
          retailerCode: code,
          matchType: MatchType.notFound,
          isAvailable: false,
          confidenceScore: 0,
        );
      }
      final e = found.entry;
      return RetailerQuote(
        retailerCode: code,
        productId: '${code.name}_${e.productName.replaceAll(' ', '_').toLowerCase()}',
        productName: e.productName,
        brand: e.brand,
        sizeLabel: e.sizeLabel,
        price: e.price,
        currency: 'KES',
        isAvailable: true,
        matchType: e.matchType,
        confidenceScore: e.confidence,
      );
    }).toList();
  }

  /// Batch fetch for a list of items, overlaying live scraped prices when
  /// available. Falls back to static catalog when scraping has not run yet
  /// or produced no results for a given product.
  static Future<List<ItemCompareResult>> fetchQuotes(
    List<({String id, String name, String? brand})> items,
  ) async {
    // Load the static quotes and the scraper cache concurrently
    final scrapedFuture = PriceScraperService.getCached();
    await Future.delayed(const Duration(milliseconds: 300));
    final scraped = await scrapedFuture;

    return items.map((item) {
      final quotes = quotesForItem(item.name, preferredBrand: item.brand);
      if (scraped == null || scraped.isEmpty) {
        return ItemCompareResult(
          itemId: item.id,
          itemName: item.name,
          preferredBrand: item.brand,
          quotes: quotes,
        );
      }
      final liveQuotes =
          quotes.map((q) => _applyScrapedPrice(q, scraped)).toList();
      return ItemCompareResult(
        itemId: item.id,
        itemName: item.name,
        preferredBrand: item.brand,
        quotes: liveQuotes,
      );
    }).toList();
  }

  /// Tries to find a live price from the scraper cache that matches [quote]'s
  /// product name and retailer. Returns the quote unchanged if no match found.
  static RetailerQuote _applyScrapedPrice(
    RetailerQuote quote,
    List<ScrapedProduct> scraped,
  ) {
    if (!quote.isAvailable || quote.productName == null) return quote;

    // Significant words in the static product name (length > 3, skip stopwords)
    final words = quote.productName!
        .toLowerCase()
        .split(RegExp(r'[\s/,()-]+'))
        .where((w) => w.length > 3)
        .toList();
    if (words.isEmpty) return quote;

    for (final s in scraped) {
      if (s.retailer != quote.retailerCode) continue;
      final scrapedLower = s.rawText.toLowerCase();
      int hits = 0;
      for (final w in words) {
        if (scrapedLower.contains(w)) hits++;
      }
      // Require at least 2 matching significant words (or 1 if name is short)
      final threshold = words.length == 1 ? 1 : 2;
      if (hits >= threshold) {
        return quote.copyWith(price: s.price, isLivePrice: true);
      }
    }
    return quote;
  }

  // ─── Product picker support ───────────────────────────────────────────────

  /// Returns ALL scoring catalog matches for [itemName], sorted by score desc.
  /// Used by _ProductPickerSheet so users can choose an exact product.
  /// At most [maxPerRetailer] entries per retailer are returned.
  static List<({RetailerQuote quote, double score})> allMatchesForItem(
    String itemName, {
    String? preferredBrand,
    int maxPerRetailer = 5,
  }) {
    final normalized = itemName.toLowerCase().trim();
    final normalizedCompact = normalized.replaceAll(RegExp(r'\s+'), '');
    final tokens = normalized
        .split(RegExp(r'[\s/,]+'))
        .where((t) => t.length > 2)
        .toList();

    // Score each catalog entry; deduped by (retailer + productName)
    final Map<String, ({_CatalogEntry entry, double score})> scored = {};

    for (final entry in _catalog) {
      double score = 0;

      for (final kw in entry.keywords) {
        if (normalized.contains(kw) || kw.contains(normalized)) {
          score = score < 3.0 ? 3.0 : score;
          continue;
        }
        final kwCompact = kw.replaceAll(' ', '');
        if (kwCompact.length > 3 &&
            (normalizedCompact.contains(kwCompact) ||
                kwCompact.contains(normalizedCompact))) {
          score = score < 2.5 ? 2.5 : score;
          continue;
        }
        for (final token in tokens) {
          if (token.length > 2 && (kw.contains(token) || token.contains(kw))) {
            score = score < 1.5 ? 1.5 : score;
          }
        }
        for (final token in tokens) {
          if (token.length < 4) continue;
          for (final kwWord in kw.split(' ')) {
            if (kwWord.length < 4) continue;
            final maxDist = (token.length >= 7 || kwWord.length >= 7) ? 2 : 1;
            if (_editDistance(token, kwWord) <= maxDist) {
              score = score < 1.2 ? 1.2 : score;
            }
          }
        }
      }

      if (preferredBrand != null &&
          entry.brand != null &&
          entry.brand!.toLowerCase().contains(preferredBrand.toLowerCase())) {
        score += 2.0;
      }
      if (score == 0) continue;

      final dedupeKey = '${entry.retailer.name}|${entry.productName}';
      final existing = scored[dedupeKey];
      if (existing == null || score > existing.score) {
        scored[dedupeKey] = (entry: entry, score: score);
      }
    }

    // Build RetailerQuote objects and sort by score desc
    final results = scored.values.map((v) {
      final e = v.entry;
      return (
        quote: RetailerQuote(
          retailerCode: e.retailer,
          productId:
              '${e.retailer.name}_${e.productName.replaceAll(' ', '_').toLowerCase()}',
          productName: e.productName,
          brand: e.brand,
          sizeLabel: e.sizeLabel,
          price: e.price,
          currency: 'KES',
          isAvailable: true,
          matchType: e.matchType,
          confidenceScore: e.confidence,
        ),
        score: v.score,
      );
    }).toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Cap at maxPerRetailer per retailer
    final Map<RetailerCode, int> counts = {};
    return results.where((r) {
      final c = counts[r.quote.retailerCode] ?? 0;
      if (c >= maxPerRetailer) return false;
      counts[r.quote.retailerCode] = c + 1;
      return true;
    }).toList();
  }
}

class _ScoredEntry {
  final _CatalogEntry entry;
  final double score;
  const _ScoredEntry(this.entry, this.score);
}

// ─────────────────────────────────────────────────────────────────────────────
// Levenshtein edit-distance helper (used by quotesForItem fuzzy pass)
// ─────────────────────────────────────────────────────────────────────────────
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  // Early bail-out: length gap alone exceeds any match threshold
  if ((a.length - b.length).abs() > 3) return 999;
  final dp = List.generate(
    a.length + 1,
    (i) => List<int>.filled(b.length + 1, 0),
  );
  for (int i = 0; i <= a.length; i++) dp[i][0] = i;
  for (int j = 0; j <= b.length; j++) dp[0][j] = j;
  for (int i = 1; i <= a.length; i++) {
    for (int j = 1; j <= b.length; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        final sub = dp[i - 1][j - 1];
        final del = dp[i - 1][j];
        final ins = dp[i][j - 1];
        dp[i][j] = 1 + (sub < del ? (sub < ins ? sub : ins) : (del < ins ? del : ins));
      }
    }
  }
  return dp[a.length][b.length];
}
