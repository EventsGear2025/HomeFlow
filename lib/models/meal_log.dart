/// Exact per-food nutrition category mapping.
/// Every item in AppConstants.commonFoods is mapped here so the analytics
/// engine can count precise protein/carb/vegetable occurrences.
const Map<String, List<String>> foodNutritionMap = {
  // ── BREAKFAST ───────────────────────────────────────────
  'Tea with Milk':     ['Dairy', 'Hydration'],
  'Black Tea':         ['Hydration'],
  'Porridge':          ['Carbs'],
  'Uji':               ['Carbs', 'Dairy'],
  'Bread':             ['Carbs'],
  'Mandazi':           ['Carbs'],
  'Chapati':           ['Carbs'],
  'Sweet Potatoes':    ['Carbs'],
  'Arrowroots':        ['Carbs'],
  'Nduma':             ['Carbs'],
  'Boiled Eggs':       ['Protein'],
  'Fried Eggs':        ['Protein'],
  'Omelette':          ['Protein'],
  'Sausages':          ['Protein'],
  'Smokies':           ['Protein'],
  'Cornflakes':        ['Carbs'],
  'Oats':              ['Carbs'],
  'Fruit':             ['Fruit'],
  'Milk':              ['Dairy'],
  // ── SNACKS ──────────────────────────────────────────────
  'Banana':            ['Fruit'],
  'Orange':            ['Fruit'],
  'Mango':             ['Fruit'],
  'Pawpaw':            ['Fruit'],
  'Watermelon':        ['Fruit'],
  'Avocado':           ['Fruit'],
  'Boiled Egg':        ['Protein'],
  'Groundnuts':        ['Protein'],
  'Roasted Maize':     ['Carbs'],
  'Biscuits':          ['Carbs'],
  'Yoghurt':           ['Dairy'],
  'Juice':             ['Hydration'],
  'Leftover Chapati':  ['Carbs'],
  // ── UGALI MEALS ─────────────────────────────────────────
  'Ugali & Sukuma Wiki':             ['Carbs', 'Vegetables'],
  'Ugali & Cabbage':                 ['Carbs', 'Vegetables'],
  'Ugali & Spinach':                 ['Carbs', 'Vegetables'],
  'Ugali & Beef Stew':               ['Carbs', 'Protein'],
  'Ugali & Chicken Stew':            ['Carbs', 'Protein'],
  'Ugali & Omena':                   ['Carbs', 'Protein'],
  'Ugali & Pumpkin Leaves':          ['Carbs', 'Vegetables'],
  'Ugali & Traditional Vegetables':  ['Carbs', 'Vegetables'],
  'Ugali & Fried Fish':              ['Carbs', 'Protein'],
  // ── RICE MEALS ──────────────────────────────────────────
  'Rice & Beans':                   ['Carbs', 'Protein'],
  'Rice & Beef Stew':               ['Carbs', 'Protein'],
  'Rice & Chicken Stew':            ['Carbs', 'Protein'],
  'Rice & Green Grams (Ndengu)':    ['Carbs', 'Protein'],
  'Rice & Lentils':                 ['Carbs', 'Protein'],
  'Rice & Vegetables':              ['Carbs', 'Vegetables'],
  'Pilau':                          ['Carbs', 'Protein'],
  // ── CHAPATI MEALS ───────────────────────────────────────
  'Chapati & Beans':     ['Carbs', 'Protein'],
  'Chapati & Ndengu':    ['Carbs', 'Protein'],
  'Chapati & Beef Stew': ['Carbs', 'Protein'],
  'Chapati & Chicken':   ['Carbs', 'Protein'],
  'Chapati & Lentils':   ['Carbs', 'Protein'],
  // ── OTHER STAPLES ────────────────────────────────────────
  'Githeri':               ['Carbs', 'Protein'],
  'Mukimo & Stew':         ['Carbs', 'Protein', 'Vegetables'],
  'Matoke & Beef':         ['Carbs', 'Protein'],
  'Matoke & Vegetables':   ['Carbs', 'Vegetables'],
  'Potatoes & Beef Stew':  ['Carbs', 'Protein'],
  'Potatoes & Cabbage':    ['Carbs', 'Vegetables'],
  'Spaghetti & Minced Meat': ['Carbs', 'Protein'],
  'Noodles & Eggs':        ['Carbs', 'Protein'],
  'Boiled Maize & Beans':  ['Carbs', 'Protein'],
  // ── PROTEINS & SIDES ────────────────────────────────────
  'Beef Stew':         ['Protein'],
  'Wet-fried Beef':    ['Protein'],
  'Minced Beef':       ['Protein'],
  'Kienyeji Chicken':  ['Protein'],
  'Broiler Chicken':   ['Protein'],
  'Fried Fish':        ['Protein'],
  'Fish Stew':         ['Protein'],
  'Goat Meat':         ['Protein'],
  'Beans':             ['Protein'],
  'Ndengu':            ['Protein'],
  'Lentils':           ['Protein'],
  'Omena':             ['Protein'],
  // ── VEGETABLES ──────────────────────────────────────────
  'Sukuma Wiki':           ['Vegetables'],
  'Spinach':               ['Vegetables'],
  'Cabbage':               ['Vegetables'],
  'Tomatoes':              ['Vegetables'],
  'Onions':                ['Vegetables'],
  'Carrots':               ['Vegetables'],
  'Green Peas':            ['Vegetables'],
  'Capsicum':              ['Vegetables'],
  'Kachumbari':            ['Vegetables'],
  'Dhania':                ['Vegetables'],
  'Spring Onions':         ['Vegetables'],
  'Pumpkin Leaves':        ['Vegetables'],
  'Traditional Vegetables':['Vegetables'],
  // ── FRUITS ──────────────────────────────────────────────
  'Pineapple':    ['Fruit'],
  'Apple':        ['Fruit'],
  'Passion Fruit':['Fruit'],
  // ── DAIRY & DRINKS ──────────────────────────────────────
  'Water':      ['Hydration'],
  'Tea':        ['Hydration'],
};

class MealLog {
  final String id;
  final String householdId;
  final DateTime date;
  final String mealPeriod;
  final List<String> selectedFoods;
  final String? childId;
  final String? childName;
  final bool packedForSchool;
  final List<String> nutritionTags;
  final String? notes;
  final String createdByUserId;

  MealLog({
    required this.id,
    required this.householdId,
    required this.date,
    required this.mealPeriod,
    required this.selectedFoods,
    this.childId,
    this.childName,
    this.packedForSchool = false,
    required this.nutritionTags,
    this.notes,
    required this.createdByUserId,
  });

  /// Derives nutrition tags by looking up each food in [foodNutritionMap].
  /// Falls back to keyword matching for any custom / free-text food entries.
  static List<String> deriveNutritionTags(List<String> foods) {
    final tags = <String>{};
    for (final food in foods) {
      final mapped = foodNutritionMap[food];
      if (mapped != null) {
        tags.addAll(mapped);
        continue;
      }
      // Fallback keyword scan for custom entries
      final lower = food.toLowerCase();
      const carbKw    = ['bread','ugali','rice','chapati','mandazi','maize',
        'githeri','mukimo','matoke','porridge','uji','pasta','spaghetti',
        'noodles','potato','arrowroot','nduma','biscuit','cornflake','oat','pilau'];
      const proteinKw = ['egg','omelette','bean','lentil','ndengu','green gram',
        'chicken','kienyeji','broiler','beef','stew','wet-fry','minced','fish',
        'omena','sausage','smokie','goat','groundnut',
        // exotic & additional proteins
        'meat','pork','lamb','mutton','turkey','duck','venison','rabbit',
        'ostrich','camel','quail','tilapia','tuna','salmon','sardine','prawn',
        'shrimp','lobster','crab','nyama','nyam'];
      const vegKw     = ['sukuma','cabbage','spinach','carrot','pea','onion',
        'capsicum','kachumbari','dhania','tomato','vegetable','pumpkin'];
      const fruitKw   = ['banana','mango','orange','apple','watermelon',
        'avocado','pawpaw','pineapple','passion','fruit'];
      const dairyKw   = ['milk','yoghurt','cheese','uji'];
      const drinkKw   = ['tea','coffee','water','juice'];
      if (carbKw.any((k)   => lower.contains(k))) tags.add('Carbs');
      if (proteinKw.any((k)=> lower.contains(k))) tags.add('Protein');
      if (vegKw.any((k)    => lower.contains(k))) tags.add('Vegetables');
      if (fruitKw.any((k)  => lower.contains(k))) tags.add('Fruit');
      if (dairyKw.any((k)  => lower.contains(k))) tags.add('Dairy');
      if (drinkKw.any((k)  => lower.contains(k))) tags.add('Hydration');
    }
    return tags.toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'householdId': householdId,
        'date': date.toIso8601String(),
        'mealPeriod': mealPeriod,
        'selectedFoods': selectedFoods,
        'childId': childId,
        'childName': childName,
        'packedForSchool': packedForSchool,
        'nutritionTags': nutritionTags,
        'notes': notes,
        'createdByUserId': createdByUserId,
      };

  factory MealLog.fromJson(Map<String, dynamic> json) => MealLog(
        id: json['id'],
        householdId: json['householdId'],
        date: DateTime.parse(json['date']),
        mealPeriod: json['mealPeriod'],
        selectedFoods: List<String>.from(json['selectedFoods']),
        childId: json['childId'],
        childName: json['childName'],
        packedForSchool: json['packedForSchool'] ?? false,
        nutritionTags: List<String>.from(json['nutritionTags']),
        notes: json['notes'],
        createdByUserId: json['createdByUserId'],
      );
}
