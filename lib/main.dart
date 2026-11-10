import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'service_locator.dart';
import 'theme.dart';
import 'blocs/category_bloc.dart';
import 'blocs/inventory_bloc.dart';
import 'blocs/rating_bloc.dart';
import 'blocs/settings_bloc.dart';
import 'services/claude_api_service.dart';
import 'services/database_service.dart';
import 'services/elo_service.dart';
import 'services/json_export_service.dart';
import 'services/photo_storage_service.dart';
import 'services/segmentation_service.dart';
import 'services/settings_service.dart';
import 'screens/inventory_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await setupServiceLocator();
  runApp(const BroomApp());
}

class BroomApp extends StatelessWidget {
  const BroomApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => CategoryBloc(getIt<DatabaseService>())..add(LoadCategories())),
        BlocProvider(create: (_) => InventoryBloc(getIt<DatabaseService>())..add(LoadItems())),
        BlocProvider(create: (_) => RatingBloc(getIt<DatabaseService>(), getIt<EloService>())),
        BlocProvider(create: (_) => SettingsBloc(
          getIt<SettingsService>(),
          getIt<ClaudeApiService>(),
          getIt<DatabaseService>(),
          getIt<PhotoStorageService>(),
          getIt<SegmentationService>(),
          getIt<JsonExportService>(),
        )..add(LoadSettings())),
      ],
      child: MaterialApp(
        title: 'Broom',
        theme: buildAppTheme(),
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final _inventoryKey = GlobalKey<InventoryScreenState>();
  final _ratingKey = GlobalKey<RatingScreenState>();

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  late final List<Widget> _screens = [
    InventoryScreen(key: _inventoryKey),
    RatingScreen(key: _ratingKey, onSwitchToInventory: () => switchToTab(0)),
    const SettingsScreen(),
  ];

  static const _tabLabels = ['Inventory', 'Rating', 'Settings'];
  static const _tabIcons = [Icons.inventory_2, Icons.star, Icons.settings];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: kColorFill,
            border: Border(top: BorderSide(color: kColorBlack.withValues(alpha: 0.08), width: kBorderWidth)),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: List.generate(_tabLabels.length, (index) {
                final selected = _currentIndex == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (index == 0) {
                        _inventoryKey.currentState?.refreshItems();
                      } else if (index == 1) {
                        _ratingKey.currentState?.refreshCurrentItems();
                      }
                      setState(() => _currentIndex = index);
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, kSpace, 0, kSpace),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _tabIcons[index],
                            size: kIconSize,
                            color: selected ? kColorBlack : kColorGrey,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _tabLabels[index],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.instrumentSans(
                              fontSize: kFontSize,
                              color: selected ? kColorBlack : kColorGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
