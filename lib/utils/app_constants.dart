class AppConstants {
  // Plan limits
  static const int freeMaxSupplies = 60;  // covers full Kenyan starter inventory
  static const int freeMaxChildren = 2;
  static const int freeMaxLaundryZones = 2;

  // Gas tracking
  static const int gasExpectedDurationDays = 42; // 6 weeks
  static const int gasEarlyAlertDays = 35;       // week 5

  // Supply categories — Kenyan household taxonomy
  static const List<String> supplyCategories = [
    'Breakfast Staples',
    'Dry Foods & Cereals',
    'Vegetables',
    'Fruits',
    'Meat & Protein',
    'Dairy & Eggs',
    'Cooking Essentials',
    'Kitchen Cleaning',
    'Laundry & Cleaning',
    'Personal Care',
    'Baby & Kids',
    'Other',
  ];

  // Unit types
  static const List<String> unitTypes = [
    'packet',
    'litre',
    'kg',
    'bottle',
    'loaf',
    'tray',
    'bunch',
    'cylinder',
    'bar',
    'roll',
    'piece',
    'bag',
    'crate',
    'sachet',
    'tin',
  ];

  // Meal periods — Kenyan household rhythm
  static const List<String> mealPeriods = [
    'Breakfast',
    'School Snack',
    'Lunch',
    'After-school Snack',
    'Dinner',
  ];

  // Laundry bedrooms (also defined in laundry_item.dart as bedroomOptions)
  static const List<String> laundryBedrooms = [
    'Bedroom 1',
    'Bedroom 2',
    'Bedroom 3',
    'Bedroom 4',
    'Master Bedroom',
    'Staff Bedroom',
  ];

  // Laundry stages
  static const List<String> laundryStages = [
    'Pending Wash',
    'Washing',
    'Drying',
    'Ironing',
    'Folded',
    'Ready',
  ];

  // Common Kenyan household food items — organised by meal period context.
  // Each category is collapsible in the Log Meal sheet.
  static const Map<String, List<String>> commonFoods = {
    // ── BREAKFAST ────────────────────────────────────────────────────
    'Breakfast': [
      'Tea with Milk',
      'Black Tea',
      'Porridge',
      'Uji',
      'Bread',
      'Mandazi',
      'Chapati',
      'Sweet Potatoes',
      'Arrowroots',
      'Nduma',
      'Boiled Eggs',
      'Fried Eggs',
      'Omelette',
      'Sausages',
      'Smokies',
      'Cornflakes',
      'Oats',
      'Fruit',
      'Milk',
    ],
    // ── SCHOOL & AFTER-SCHOOL SNACKS ─────────────────────────────────
    'Snacks': [
      'Mandazi',
      'Banana',
      'Orange',
      'Mango',
      'Pawpaw',
      'Watermelon',
      'Avocado',
      'Boiled Egg',
      'Groundnuts',
      'Roasted Maize',
      'Biscuits',
      'Yoghurt',
      'Bread',
      'Juice',
      'Leftover Chapati',
    ],
    // ── UGALI MEALS ───────────────────────────────────────────────────
    'Ugali Meals': [
      'Ugali & Sukuma Wiki',
      'Ugali & Cabbage',
      'Ugali & Spinach',
      'Ugali & Beef Stew',
      'Ugali & Chicken Stew',
      'Ugali & Omena',
      'Ugali & Pumpkin Leaves',
      'Ugali & Traditional Vegetables',
      'Ugali & Fried Fish',
    ],
    // ── RICE MEALS ────────────────────────────────────────────────────
    'Rice Meals': [
      'Rice & Beans',
      'Rice & Beef Stew',
      'Rice & Chicken Stew',
      'Rice & Green Grams (Ndengu)',
      'Rice & Lentils',
      'Rice & Vegetables',
      'Pilau',
    ],
    // ── CHAPATI MEALS ─────────────────────────────────────────────────
    'Chapati Meals': [
      'Chapati & Beans',
      'Chapati & Ndengu',
      'Chapati & Beef Stew',
      'Chapati & Chicken',
      'Chapati & Lentils',
    ],
    // ── OTHER STAPLE MEALS ────────────────────────────────────────────
    'Other Staples': [
      'Githeri',
      'Mukimo & Stew',
      'Matoke & Beef',
      'Matoke & Vegetables',
      'Potatoes & Beef Stew',
      'Potatoes & Cabbage',
      'Spaghetti & Minced Meat',
      'Noodles & Eggs',
      'Boiled Maize & Beans',
    ],
    // ── PROTEINS / SIDES ─────────────────────────────────────────────
    'Proteins & Sides': [
      'Beef Stew',
      'Wet-fried Beef',
      'Minced Beef',
      'Kienyeji Chicken',
      'Broiler Chicken',
      'Fried Fish',
      'Fish Stew',
      'Goat Meat',
      'Beans',
      'Ndengu',
      'Lentils',
      'Omena',
      'Boiled Eggs',
      'Omelette',
      'Groundnuts',
    ],
    // ── VEGETABLES & SIDES ────────────────────────────────────────────
    'Vegetables': [
      'Sukuma Wiki',
      'Spinach',
      'Cabbage',
      'Tomatoes',
      'Onions',
      'Carrots',
      'Green Peas',
      'Capsicum',
      'Kachumbari',
      'Avocado',
      'Dhania',
      'Spring Onions',
      'Pumpkin Leaves',
      'Traditional Vegetables',
    ],
    // ── FRUITS ────────────────────────────────────────────────────────
    'Fruits': [
      'Banana',
      'Avocado',
      'Mango',
      'Orange',
      'Watermelon',
      'Pawpaw',
      'Pineapple',
      'Apple',
      'Passion Fruit',
    ],
    // ── DAIRY & DRINKS ────────────────────────────────────────────────
    'Dairy & Drinks': [
      'Milk',
      'Yoghurt',
      'Tea with Milk',
      'Black Tea',
      'Uji',
      'Water',
      'Juice',
    ],
  };

  // Preloaded Kenyan household starter inventory — grouped by Naivas-style
  // categories. Covers kitchen staples, fresh market items, and cleaning.
  static const List<Map<String, dynamic>> starterSupplies = [
    // ── BREAKFAST STAPLES ────────────────────────────────────────────
    {'name': 'Tea Leaves', 'category': 'Breakfast Staples', 'unit': 'packet'},
    {'name': 'Milk', 'category': 'Breakfast Staples', 'unit': 'litre'},
    {'name': 'Bread', 'category': 'Breakfast Staples', 'unit': 'loaf'},
    {'name': 'Eggs', 'category': 'Breakfast Staples', 'unit': 'tray'},
    {'name': 'Mandazi', 'category': 'Breakfast Staples', 'unit': 'piece'},
    {'name': 'Cornflakes', 'category': 'Breakfast Staples', 'unit': 'packet'},
    // ── DRY FOODS & CEREALS ──────────────────────────────────────────
    {'name': 'Maize Flour', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Wheat Flour', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Rice', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Beans', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Green Grams (Ndengu)', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Sugar', 'category': 'Dry Foods & Cereals', 'unit': 'kg'},
    {'name': 'Salt', 'category': 'Dry Foods & Cereals', 'unit': 'packet'},
    {'name': 'Pasta / Spaghetti', 'category': 'Dry Foods & Cereals', 'unit': 'packet'},
    // ── VEGETABLES ───────────────────────────────────────────────────
    {'name': 'Tomatoes', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Onions', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Sukuma Wiki', 'category': 'Vegetables', 'unit': 'bunch'},
    {'name': 'Spinach', 'category': 'Vegetables', 'unit': 'bunch'},
    {'name': 'Cabbage', 'category': 'Vegetables', 'unit': 'piece'},
    {'name': 'Carrots', 'category': 'Vegetables', 'unit': 'bunch'},
    {'name': 'Potatoes', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Sweet Potatoes', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Arrowroots (Nduma)', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Green Peas', 'category': 'Vegetables', 'unit': 'kg'},
    {'name': 'Capsicum', 'category': 'Vegetables', 'unit': 'piece'},
    {'name': 'Dhania (Coriander)', 'category': 'Vegetables', 'unit': 'bunch'},
    // ── FRUITS ───────────────────────────────────────────────────────
    {'name': 'Bananas', 'category': 'Fruits', 'unit': 'bunch'},
    {'name': 'Avocados', 'category': 'Fruits', 'unit': 'piece'},
    {'name': 'Oranges', 'category': 'Fruits', 'unit': 'piece'},
    {'name': 'Mangoes', 'category': 'Fruits', 'unit': 'piece'},
    {'name': 'Watermelon', 'category': 'Fruits', 'unit': 'piece'},
    {'name': 'Pawpaw', 'category': 'Fruits', 'unit': 'piece'},
    // ── MEAT & PROTEIN ───────────────────────────────────────────────
    {'name': 'Beef', 'category': 'Meat & Protein', 'unit': 'kg'},
    {'name': 'Chicken', 'category': 'Meat & Protein', 'unit': 'piece'},
    {'name': 'Fish', 'category': 'Meat & Protein', 'unit': 'kg'},
    {'name': 'Minced Beef', 'category': 'Meat & Protein', 'unit': 'kg'},
    {'name': 'Goat Meat', 'category': 'Meat & Protein', 'unit': 'kg'},
    {'name': 'Sausages', 'category': 'Meat & Protein', 'unit': 'packet'},
    {'name': 'Eggs', 'category': 'Dairy & Eggs', 'unit': 'tray'},
    {'name': 'Milk', 'category': 'Dairy & Eggs', 'unit': 'litre'},
    {'name': 'Yoghurt', 'category': 'Dairy & Eggs', 'unit': 'bottle'},
    // ── COOKING ESSENTIALS ───────────────────────────────────────────
    {'name': 'Cooking Oil', 'category': 'Cooking Essentials', 'unit': 'litre'},
    {'name': 'Margarine / Butter', 'category': 'Cooking Essentials', 'unit': 'packet'},
    {'name': 'Tomato Paste', 'category': 'Cooking Essentials', 'unit': 'tin'},
    {'name': 'Stock Cubes', 'category': 'Cooking Essentials', 'unit': 'packet'},
    // ── KITCHEN CLEANING ─────────────────────────────────────────────
    {'name': 'Dishwashing Paste', 'category': 'Kitchen Cleaning', 'unit': 'tin'},
    {'name': 'Pot Scrubbers / Sponges', 'category': 'Kitchen Cleaning', 'unit': 'piece'},
    {'name': 'Scouring Powder (Vim)', 'category': 'Kitchen Cleaning', 'unit': 'tin'},
    {'name': 'Kitchen Cleaner', 'category': 'Kitchen Cleaning', 'unit': 'bottle'},
    {'name': 'Multipurpose Bar Soap', 'category': 'Kitchen Cleaning', 'unit': 'bar'},
    {'name': 'Dish Cloths / Drying Towels', 'category': 'Kitchen Cleaning', 'unit': 'piece'},
    // ── LAUNDRY & CLEANING ───────────────────────────────────────────
    {'name': 'Hand-wash Detergent Powder', 'category': 'Laundry & Cleaning', 'unit': 'packet'},
    {'name': 'Machine-wash Detergent', 'category': 'Laundry & Cleaning', 'unit': 'packet'},
    {'name': 'Bar Soap (Sunlight / Menengai)', 'category': 'Laundry & Cleaning', 'unit': 'bar'},
    {'name': 'Bleach (Jik)', 'category': 'Laundry & Cleaning', 'unit': 'bottle'},
    {'name': 'Toilet Cleaner (Harpic)', 'category': 'Laundry & Cleaning', 'unit': 'bottle'},
    {'name': 'Multipurpose Cleaner', 'category': 'Laundry & Cleaning', 'unit': 'bottle'},
    {'name': 'Toilet Paper', 'category': 'Laundry & Cleaning', 'unit': 'roll'},
    {'name': 'Tissue', 'category': 'Laundry & Cleaning', 'unit': 'packet'},
    // ── PERSONAL CARE ────────────────────────────────────────────────
    {'name': 'Body Soap', 'category': 'Personal Care', 'unit': 'bar'},
    {'name': 'Toothpaste', 'category': 'Personal Care', 'unit': 'piece'},
    {'name': 'Shampoo', 'category': 'Personal Care', 'unit': 'bottle'},
    {'name': 'Hand Sanitiser', 'category': 'Personal Care', 'unit': 'bottle'},
  ];
}
