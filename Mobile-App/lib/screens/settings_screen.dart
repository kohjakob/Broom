import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../blocs/category_bloc.dart';
import '../blocs/inventory_bloc.dart';
import '../blocs/settings_bloc.dart';
import '../modals/add_category_modal.dart';
import '../modals/category_detail_modal.dart';
import '../widgets/chip.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsBloc get _settingsBloc => context.read<SettingsBloc>();
  late final TextEditingController _apiKeyController;
  final GlobalKey _exportButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
  }

  /// iPad requires a source rect to anchor the share sheet popover; on iPhone
  /// it's ignored. Falls back to a safe default if the key isn't attached yet.
  Rect _shareAnchorRect() {
    final ctx = _exportButtonKey.currentContext;
    if (ctx != null) {
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        final offset = box.localToGlobal(Offset.zero);
        return offset & box.size;
      }
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _importJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    _settingsBloc.add(ImportData(file));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: BlocConsumer<SettingsBloc, SettingsState>(
            listenWhen: (prev, curr) =>
                (prev.apiKey != curr.apiKey && _apiKeyController.text != curr.apiKey) ||
                prev.exportedFile != curr.exportedFile ||
                prev.importResult != curr.importResult ||
                prev.dataError != curr.dataError,
            listener: (context, state) async {
              if (state.apiKey != _apiKeyController.text) {
                _apiKeyController.text = state.apiKey;
              }
              if (state.importResult != null && state.dataError == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported ${state.importResult!.itemsImported} items and ${state.importResult!.categoriesImported} categories')),
                );
                context.read<InventoryBloc>().add(RefreshItems());
                context.read<CategoryBloc>().add(LoadCategories());
              }
              if (state.dataError != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.dataError!)),
                );
              }
              // Export share must run last — it awaits and turns everything
              // after it into an async gap. Keeping non-async work above keeps
              // the BuildContext-across-async-gap lints clean.
              if (state.exportedFile != null) {
                final file = state.exportedFile!;
                // Clear state immediately so a future export re-triggers the
                // listener cleanly and we don't re-share on unrelated rebuilds.
                _settingsBloc.add(ClearExportedFile());
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: 'Broom export',
                    sharePositionOrigin: _shareAnchorRect(),
                  );
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Share failed: $e')),
                  );
                }
              }
            },
            builder: (context, state) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(kSpace, kSpace, kSpace, kSpace),
                children: [
                  // Claude API Key
                  const Text('Claude API Key', style: TextStyle(fontSize: kFontSize, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text(
                    'Used to predict item names and categories from photos, so you can add items faster.',
                    style: TextStyle(fontSize: kFontSize, color: kColorGrey),
                  ),
                  const SizedBox(height: kSpace),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            hintText: 'sk-ant-...',
                          ),
                          onChanged: (value) {
                            _settingsBloc.add(UpdateApiKey(value));
                          },
                        ),
                      ),
                      const SizedBox(width: kSpace),
                      SizedBox(
                        width: 120,
                        child: OutlinedButton(
                          onPressed: state.testStatus == TestStatus.testing
                              ? null
                              : () => _settingsBloc.add(TestApiKey()),
                          child: state.testStatus == TestStatus.testing
                              ? const SizedBox(width: kSpinnerSize, height: kSpinnerSize, child: CircularProgressIndicator(strokeWidth: 2))
                              : state.testStatus == TestStatus.success
                                  ? const Icon(Icons.check_circle, color: kColorBlack, size: kIconSize)
                                  : state.testStatus == TestStatus.failure
                                      ? const Icon(Icons.close, color: kColorError, size: kIconSize)
                                      : const Text('Test API Key'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace),

                  // Show segmented photos toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Show segmented photos', style: TextStyle(fontSize: kFontSize, fontWeight: FontWeight.w500)),
                            SizedBox(height: 4),
                            Text(
                              'Display items with background removed. Backgrounds are always removed and saved regardless.',
                              style: TextStyle(fontSize: kFontSize, color: kColorGrey),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: kSpace),
                      Switch.adaptive(
                        value: state.showSegmented,
                        onChanged: (value) => _settingsBloc.add(ToggleShowSegmented(value)),
                        activeTrackColor: kColorBlack,
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace),

                  // Edit Categories
                  const Text('Edit Categories', style: TextStyle(fontSize: kFontSize, fontWeight: FontWeight.w500)),
                  const SizedBox(height: kSpace),
                  BlocBuilder<CategoryBloc, CategoryState>(
                    builder: (context, categoryState) {
                      if (categoryState.categories.isEmpty) {
                        return const Text('No categories yet', style: TextStyle(fontSize: kFontSize, color: kColorGrey));
                      }
                      return SizedBox(
                        height: kElementHeight,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: EdgeInsets.zero,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
                              child: GestureDetector(
                                onTap: () async {
                                  final result = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => const AddCategoryModal(),
                                  );
                                  if (result == true && context.mounted) {
                                    context.read<CategoryBloc>().add(LoadCategories());
                                  }
                                },
                                child: Container(
                                  height: kElementHeight,
                                  padding: const EdgeInsets.fromLTRB(kSpace * 2, 0, kSpace * 2, 0),
                                  decoration: BoxDecoration(
                                    color: kColorWhite,
                                    border: Border.all(color: kColorBlack, width: kBorderWidth),
                                    borderRadius: BorderRadius.circular(kBorderRadiusPill),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '+',
                                      style: GoogleFonts.instrumentSans(
                                        fontSize: kFontSize,
                                        fontWeight: FontWeight.w700,
                                        color: kColorBlack,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ...categoryState.categories.map((category) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, kSpace, 0),
                              child: AppChip(
                                label: category.name,
                                emoji: category.emoji,
                                onTap: () async {
                                  final result = await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    useSafeArea: true,
                                    builder: (_) => CategoryDetailModal(category: category),
                                  );
                                  if (result == true && context.mounted) {
                                    context.read<CategoryBloc>().add(LoadCategories());
                                  }
                                },
                              ),
                            );
                          }),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: kSpace),

                  // Export/Import
                  const Text('Data', style: TextStyle(fontSize: kFontSize, fontWeight: FontWeight.w500)),
                  const SizedBox(height: kSpace),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: _exportButtonKey,
                          onPressed: state.dataOpStatus == DataOpStatus.exporting
                              ? null
                              : () => _settingsBloc.add(ExportData()),
                          child: state.dataOpStatus == DataOpStatus.exporting
                              ? const SizedBox(width: kSpinnerSize, height: kSpinnerSize, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Export'),
                        ),
                      ),
                      const SizedBox(width: kSpace),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: state.dataOpStatus == DataOpStatus.importing
                              ? null
                              : _importJson,
                          child: state.dataOpStatus == DataOpStatus.importing
                              ? const SizedBox(width: kSpinnerSize, height: kSpinnerSize, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Import'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
    );
  }

}
