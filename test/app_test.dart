import 'dart:io';

import 'package:flutterflow_ai/flutterflow_ai.dart';
import 'package:test/test.dart';

import '../dsl/edit.dart' as checkpoint;

void main() {
  test('AVARYN design system and reusable components compile', () {
    final app = buildApp(checkpoint.buildAvarynDesignSystemTestApp);
    final project = compileApp(app).project;

    final colors = project.theme.colorScheme;
    void expectPair(dynamic color, int light, int dark, String semanticName) {
      expect(
        color.value.toInt(),
        light,
        reason: '$semanticName must retain its established light appearance',
      );
      expect(
        color.darkModeColor.value.toInt(),
        dark,
        reason: '$semanticName must use the explicit AVARYN dark token',
      );
    }

    expect(colors.darkModeEnabled, isTrue);
    expectPair(colors.primary, 0xFF171518, 0xFF1C191D, 'Elevated background');
    expectPair(colors.secondary, 0xFFA96F68, 0xFFC48A82, 'Rose Bronze');
    expectPair(colors.tertiary, 0xFFE2C2BE, 0xFFADA29E, 'Muted accent');
    expectPair(colors.alternate, 0xFFF1EAE2, 0xFF494047, 'Border and divider');
    expectPair(
      colors.primaryBackground,
      0xFFFCF8F3,
      0xFF151316,
      'Page background',
    );
    expectPair(
      colors.secondaryBackground,
      0xFFFCF8F3,
      0xFF252126,
      'Primary card surface',
    );
    expectPair(colors.primaryText, 0xFF171518, 0xFFFCF8F3, 'Primary text');
    expectPair(colors.secondaryText, 0xFF6D6460, 0xFFD8CFCA, 'Secondary text');
    expectPair(colors.accent1, 0xFFFCF8F3, 0xFFFCF8F3, 'On-dark Pearl');
    expectPair(colors.accent2, 0xFFF1EAE2, 0xFF302A30, 'Selected surface');
    expectPair(colors.accent3, 0xFFE2C2BE, 0xFF4A3034, 'Soft Rose surface');
    expectPair(colors.accent4, 0xFFFCF8F3, 0xFF1C191D, 'Navigation surface');
    expectPair(colors.success, 0xFF718577, 0xFF8FA497, 'Functional Sage');
    expectPair(colors.warning, 0xFFE7ECE8, 0xFF302A30, 'Status surface');
    expectPair(colors.error, 0xFFB65F58, 0xFFD87870, 'Alert Terracotta');
    expectPair(colors.info, 0xFF713D43, 0xFF8D525A, 'Deep Wine');

    final preview = findPage(project, name: 'AvarynDesignPreviewPage');
    expect(preview, isNotNull);
    expect(preview!.node.type, FFWidgetType.Scaffold);

    final horses = findPage(project, name: 'HorsesOverviewPage');
    expect(horses, isNotNull);
    final horsesJson = horses!.node.toProto3Json().toString();
    for (final marker in const [
      'HorsesOverviewResponsiveShell',
      'HorsesMobileHeader',
      'AddHorseButtonMobile',
      'HorseCardOrion',
      'HorseCardCeleste',
      'HorseCardVesper',
      'HorsesMobileBottomNavigation',
    ]) {
      expect(
        horsesJson,
        contains(marker),
        reason: '$marker should be present on the responsive horses page',
      );
    }
    expect(horsesJson.toLowerCase(), contains('dagvorm'));
    expect(horsesJson.toLowerCase(), isNot(contains('readiness')));
    expect(horsesJson.toLowerCase(), isNot(contains('gereedheid')));

    final today = findPage(project, name: 'TodayDashboardPage');
    expect(today, isNotNull);
    final todayJson = today!.node.toProto3Json().toString().toLowerCase();
    expect(todayJson, contains('dagvorm'));
    expect(todayJson, isNot(contains('readiness')));
    expect(todayJson, isNot(contains('gereedheid')));

    final orion = findPage(project, name: 'OrionProfilePage');
    expect(orion, isNotNull);
    final orionJson = orion!.node.toProto3Json().toString();
    for (final marker in const [
      'OrionProfileResponsiveShell',
      'OrionMobilePhotographicHeader',
      'OrionProfileSectionNavigation',
      'OrionDayFormCard',
      'OrionCurrentAttentionPanel',
      'OrionAssessmentButton',
      'OrionNextActivityPanel',
      'OrionRecentTrainingPanel',
      'OrionDevelopmentInsight',
      'OrionTemporarySectionState',
      'OrionMobileBottomNavigation',
    ]) {
      expect(
        orionJson,
        contains(marker),
        reason: '$marker should be present on the responsive Orion profile',
      );
    }
    for (final text in const [
      'North Star',
      'Roepnaam Orion',
      'Grand Prix',
      'Dagvorm',
      'Verhoogde warmte linker voorbeen',
      'Overzicht',
      'Gezondheid',
      'Training',
      'Voeding',
      'Gegevens',
      'Dit onderdeel wordt in een volgende versie uitgewerkt.',
    ]) {
      expect(orionJson, contains(text));
    }
    expect(orionJson.toLowerCase(), isNot(contains('readiness')));
    expect(orionJson.toLowerCase(), isNot(contains('gereedheid')));
    expect(findCustomWidget(project, name: 'AvarynOrionPhoto'), isNotNull);
    expect(findCustomWidget(project, name: 'AvarynHorseshoeIcon'), isNotNull);
    final horseAvatar = findCustomWidget(project, name: 'AvarynHorseAvatar');
    expect(horseAvatar, isNotNull);
    expect(horseAvatar!.code, contains('final String? photoState;'));
    expect(
      horseAvatar.code,
      contains("final normalized = (photoState ?? '').trim().toLowerCase();"),
    );
    expect(horseAvatar.code, contains('FlutterFlowTheme.of(context)'));
    expect(horseAvatar.code, contains('backgroundColor: theme.accent2'));
    expect(horseAvatar.code, contains('silhouetteColor: theme.primaryText'));
    expect(horseAvatar.code, contains('shortestSide * 0.22'));
    expect(horseAvatar.code, contains('side * 0.17, side * 0.92'));
    expect(horseAvatar.code, isNot(contains('canvas.drawCircle')));
    expect(horseAvatar.code, isNot(contains('const Color(0xFFF1EAE2)')));
    expect(horseAvatar.code, isNot(contains('const Color(0xFF171518)')));
    expect(horseAvatar.code, isNot(contains('const Color(0xFF713D43)')));

    final horseshoe = findCustomWidget(project, name: 'AvarynHorseshoeIcon');
    expect(horseshoe, isNotNull);
    expect(
      horseshoe!.code,
      contains('active ? theme.secondary : theme.secondaryText'),
    );
    expect(horseshoe.code, isNot(contains('const Color(0xFFA96F68)')));
    expect(horseshoe.code, isNot(contains('const Color(0xFF171518)')));

    for (final componentName in const [
      'AvarynLoadingState',
      'AvarynPrimaryButton',
      'AvarynSecondaryButton',
      'AvarynStatusChip',
      'AvarynProfileImage',
      'AvarynHorseSelectorCard',
      'AvarynMetricCard',
      'AvarynTaskRow',
      'AvarynMobileNavigation',
      'AvarynDesktopNavigation',
    ]) {
      expect(
        findComponent(project, name: componentName),
        isNotNull,
        reason: '$componentName should compile into the component library',
      );
    }
  });

  test('horse create and edit flows stay intentionally separated', () {
    final source = File('dsl/edit.dart').readAsStringSync();

    expect(source, contains('final horseEditPage = ff.Pages.horseEditPage;'));
    expect(source, contains("name: 'HorseEditTabs'"));
    for (final tab in const [
      'Basisgegevens',
      'Sport',
      'Identificatie',
      'Betrokkenen & locatie',
      'Foto en notities',
    ]) {
      expect(source, matches(RegExp("TabItem\\(\\s*'$tab'")));
    }
    expect(source, contains("name: 'SaveHorseEditsButton'"));
    expect(source, contains("'Wijzigingen niet opslaan?'"));
    expect(source, contains("name: 'ContinueHorseEditingButton'"));
    expect(source, contains("name: 'DiscardHorseEditsButton'"));
    expect(source, contains("TabBarControl.jumpTo('HorseEditTabs', 0)"));
    expect(source, contains("name: 'CreateHorseSubmitButton'"));
    expect(source, contains("'Paard toevoegen'"));
    expect(source, contains("'Paspoort geldig tot en met'"));
    expect(source, contains("name: 'TodayPassportExpiryWarnings'"));
    expect(source, contains("final responsiveToday = findPage("));
    expect(source, contains("'DesktopDashboardCanvas'"));
    expect(source, contains("name: 'DesktopDashboardContent'"));
    expect(source, contains("'CompactDashboardCanvas'"));
    expect(source, contains("'MobileBottomNavigation'"));
    expect(source, contains("name: 'HorseDetailDesktopContent'"));
    expect(source, contains("'HorseDetailDesktopSideNavigation'"));
    expect(source, contains("'HorseDetailCompactCanvas'"));
    expect(source, contains("'HorseDetailMobileBottomNavigation'"));
    expect(source, contains('void _applyHorsesResponsiveVisibility(App app)'));
    expect(source, contains("'HorsesDesktopSideNavigation'"));
    expect(source, contains("'HorsesCompactCanvas'"));
    expect(
      source,
      contains(
        "Container(\n                  name: 'DesktopDashboardCanvas',\n"
        '                  width: double.infinity,',
      ),
    );
    expect(
      source,
      contains(
        "Container(\n                  name: 'HorseDetailDesktopCanvas',\n"
        '                  width: double.infinity,',
      ),
    );
    expect(
      source,
      contains('app.breakpoints(small: 600, medium: 768, large: 1023);'),
    );
    expect(source, contains("'OfficiÃ«le naam:'"));
    expect(
      source,
      contains(
        "'Beheer de eigenaar, ruiter en huidige stal of locatie van het paard.'",
      ),
    );
    expect(source, isNot(contains("TabItem('Omgeving'")));
  });

  test('Planning and Vandaag share one persisted activity system', () {
    final source = File('dsl/edit.dart').readAsStringSync();
    final schemas =
        File('lib/flutterflow_project/schemas.dart').readAsStringSync();
    final appState =
        File('lib/flutterflow_project/app_state.dart').readAsStringSync();

    expect(source, contains('void buildPlanningActivityIteration(App app)'));
    expect(source, contains('final activity = ff.Structs.activityData;'));
    expect(schemas, contains('"ActivityData"'));
    for (final field in const [
      '"id": ffai.int_',
      '"activityType": ffai.string',
      '"horseId": ffai.int_',
      '"title": ffai.string',
      '"date": ffai.dateTime',
      '"time": ffai.dateTime',
      '"notes": ffai.string',
      '"isCompleted": ffai.bool_',
      '"createdAt": ffai.dateTime',
      '"updatedAt": ffai.dateTime',
    ]) {
      expect(schemas, contains(field));
    }
    expect(appState, contains('static const activities'));
    expect(appState, contains('typeName: "List<DataStruct<ActivityData>>"'));
    expect(appState, contains('persisted: true'));
    expect(source, contains("app.component(\n    'AvarynActivityCard'"));
    expect(source, contains("'ActivityHorsePickerSheet'"));
    expect(source, contains("'PlanningPage'"));
    expect(source, contains("'ActivityFormPage'"));
    expect(source, contains("'ActivityDetailPage'"));
    expect(source, contains("'Activiteit toevoegen'"));
    expect(source, contains("'Activiteit opslaan'"));
    expect(source, contains("'Vandaag gepland'"));
    expect(source, contains("'Geen activiteiten gepland voor vandaag.'"));
    expect(source, contains("UpdateAppState.updateItemAtIndex(\n"));
    expect(source, contains("UpdateAppState.removeAtIndex(\n"));
    expect(source, contains("'ActivityConfirmationSheet'"));
    expect(source, contains("ShowBottomSheet(\n"));
    expect(source, contains("'onConfirmAction': ["));
    expect(source, isNot(contains("ConfirmDialog(\n")));
    expect(source, contains('Navigate(ff.Pages.planningPage)'));
    expect(source, contains("DatePickerMode.time"));
    expect(source, contains("name: 'PlanningActivityList'"));
    expect(source, contains("name: 'ActivityFormPrimaryScroll'"));
    expect(source, contains("name: 'ActivityFormStickySaveBar'"));
    expect(source, contains('void _applyActivityResponsiveVisibility('));
    expect(source, contains('required String pageName'));
  });

  test('targeted activity refinement is typed, reusable and conflict safe', () {
    final source = File('dsl/edit.dart').readAsStringSync();
    final schemas =
        File('lib/flutterflow_project/schemas.dart').readAsStringSync();
    final appState =
        File('lib/flutterflow_project/app_state.dart').readAsStringSync();

    expect(
      source,
      contains('void buildTargetedActivityFlowRefinement(App app)'),
    );
    for (final field in const [
      '"stableId": ffai.string',
      '"customTitle": ffai.string',
      '"assigneeUserIds": ffai.listOf(ffai.string)',
      '"startDate": ffai.dateTime',
      '"endDate": ffai.dateTime',
      '"startTime": ffai.dateTime',
      '"endTime": ffai.dateTime',
      '"allDay": ffai.bool_',
      '"durationMinutes": ffai.int_',
      '"locationType": ffai.string',
      '"locationName": ffai.string',
      '"serviceProviderName": ffai.string',
      '"completionStatus": ffai.string',
    ]) {
      expect(schemas, contains(field));
    }
    expect(appState, contains('static const activityDraftAssigneeUserIds'));
    expect(appState, contains('static const activitySaveInProgress'));
    expect(appState, contains('static const currentLocalUserId'));
    expect(source, contains("'AvarynAgendaPickerSheet'"));
    expect(source, contains("'ActivityAssigneePickerSheet'"));
    expect(source, contains("'ActivityConflictSheet'"));
    expect(source, contains("'ActivityTypeChangeSheet'"));
    expect(source, contains("'Selecteer een paard'"));
    expect(source, contains("'Type activiteit'"));
    final refinedForm = source.substring(
      source.indexOf('DslWidget _activityFormFieldsV2'),
    );
    expect(
      refinedForm.indexOf("'Paard', requiredField: true"),
      lessThan(refinedForm.indexOf("'Type activiteit', requiredField: true")),
    );
    expect(source, contains("'Planning aanpassen'"));
    expect(source, contains("'Toch opslaan'"));
    expect(source, contains("'activityConflictWarningV2'"));
    expect(source, contains("'todayActivitiesV2'"));
    expect(source, contains("'activityDisplayTitleV2'"));
    expect(source, contains("'local-current-user'"));
    expect(source, isNot(contains("'Sofia'")));

    final agendaPickerSource = source.substring(
      source.indexOf('DslWidget _activityAgendaPickerSheetV2'),
      source.indexOf('DslWidget _activityAssigneePickerSheetV2'),
    );
    expect(agendaPickerSource, contains("name: 'AgendaPrimaryScroll'"));
    expect(agendaPickerSource, contains("name: 'ActivityAgendaDateGrid'"));
    expect(agendaPickerSource, contains('agendaRangeStep'));
    expect(agendaPickerSource, contains('agendaTimeDraft'));
    expect(agendaPickerSource, contains("'Datum van'"));
    expect(agendaPickerSource, contains("'Tot en met'"));
    expect(agendaPickerSource, contains("'- 5 min'"));
    expect(agendaPickerSource, contains("'+ 5 min'"));
    expect(agendaPickerSource, isNot(contains('DatePicker(')));
    expect(agendaPickerSource, isNot(contains('Calendar(')));
    expect(source, contains("'Huidige lokaal geregistreerde gebruiker'"));
    expect(source, contains("'Actief'"));
    expect(
      source,
      isNot(contains('Huidige lokaal geregistreerde gebruiker Ã')),
    );
    expect(source, contains("state.ensureField('agendaOpening'"));
    expect(source, contains("initialMode: 'startTime'"));
    expect(source, contains("initialMode: 'endTime'"));
    expect(source, contains("widgetName: 'AvarynAgendaPickerRuntime'"));
    expect(
      source,
      contains('class AvarynAgendaPickerRuntime extends StatefulWidget'),
    );
    final agendaRuntimeSource = source.substring(
      source.indexOf("const String _agendaPickerRuntimeWidgetCode"),
      source.indexOf('Future<void> main('),
    );
    expect(agendaRuntimeSource, contains('SingleChildScrollView('));
    expect(agendaRuntimeSource, contains('NeverScrollableScrollPhysics()'));
    expect(
      agendaRuntimeSource,
      contains("'startTime' => 'Starttijd instellen'"),
    );
    expect(agendaRuntimeSource, contains("'endTime' => 'Eindtijd instellen'"));
    expect(agendaRuntimeSource, contains("'Annuleren'"));
    expect(agendaRuntimeSource, contains("'Bevestigen'"));
    expect(agendaRuntimeSource, contains('FixedExtentScrollController'));
    expect(agendaRuntimeSource, contains('ListWheelScrollView.useDelegate'));
    expect(agendaRuntimeSource, contains("label: 'Uur'"));
    expect(agendaRuntimeSource, contains("label: 'Minuut'"));
    expect(agendaRuntimeSource, isNot(contains('void _adjustTime(')));
    expect(agendaRuntimeSource, isNot(contains('showDatePicker')));
    expect(agendaRuntimeSource, isNot(contains('showTimePicker')));
    final planningRuntimeSource = source.substring(
      source.indexOf("const String _planningViewsRuntimeWidgetCode"),
      source.indexOf('Future<void> main('),
    );
    expect(
      planningRuntimeSource,
      contains('class AvarynPlanningViewsRuntime extends StatefulWidget'),
    );
    expect(planningRuntimeSource, contains("'Lijst'"));
    expect(planningRuntimeSource, contains("'Agenda'"));
    expect(planningRuntimeSource, contains("'Mijn taken'"));
    expect(planningRuntimeSource, contains("'Alle taken van de stal'"));
    expect(
      planningRuntimeSource,
      contains("'Geen activiteiten gepland op deze dag.'"),
    );
    expect(planningRuntimeSource, contains('item.assigneeUserIds.contains'));
    expect(planningRuntimeSource, contains('item.stableId.trim()'));
    expect(planningRuntimeSource, contains('context.watch<FFAppState>()'));
    expect(
      planningRuntimeSource,
      contains("await context.pushNamed('ActivityDetailPage')"),
    );
    expect(source, contains("widgetName: 'AvarynPlanningViewsRuntime'"));
    expect(source, contains("'Activiteit opslaan...'"));
  });

  test('horse nutrition schema stays additive and horse-stable scoped', () {
    final schemas =
        File('lib/flutterflow_project/schemas.dart').readAsStringSync();
    final appState =
        File('lib/flutterflow_project/app_state.dart').readAsStringSync();
    final source = File('dsl/edit.dart').readAsStringSync();

    for (final structName in const [
      'FeedingItemData',
      'FeedingRoundSnapshotData',
      'HorseFeedingPlanData',
      'TemporaryFeedingScheduleData',
      'EffectiveFeedingScheduleData',
    ]) {
      expect(schemas, contains('"$structName"'));
    }
    for (final itemField in const [
      '"quantityMode": ffai.string',
      '"linkedProductId": ffai.string',
      '"sortOrder": ffai.int_',
      '"customUnitLabel": ffai.string',
    ]) {
      expect(schemas, contains(itemField));
    }
    expect(
      schemas,
      contains('"rounds": ffai.listOf(Structs.feedingRoundSnapshotData)'),
    );
    expect(
      schemas,
      contains(
        '"roundSnapshots": ffai.listOf(Structs.feedingRoundSnapshotData)',
      ),
    );
    expect(schemas, contains('"stableId": ffai.string'));
    expect(appState, contains('static const currentLocalStableId'));
    expect(appState, contains('static const horseFeedingPlans'));
    expect(appState, contains('static const temporaryFeedingSchedules'));
    expect(appState, contains('persisted: true'));
    expect(source, contains("'morning', 'Ochtend'"));
    expect(source, contains("'afternoon', 'Middag'"));
    expect(source, contains("'evening', 'Avond'"));
    expect(source, contains("'feed', 'Voer'"));
    expect(source, contains("'hay', 'Hooi'"));
    expect(source, contains("'supplements', 'Supplementen'"));
    expect(source, contains("'medication', 'Medicatie'"));
    expect(source, contains("'Onbeperkt / vrije toegang'"));
    expect(source, contains("'AVARYN registreert alleen het ingestelde '"));
    expect(source, contains("route: '/paarden/voeding'"));
    expect(source, contains("widgetName: 'AvarynHorseNutritionRuntime'"));

    final nutritionPhaseStart = source.indexOf(
      'void buildHorseNutritionPhaseOne(App app)',
    );
    final nutritionPhaseEnd = source.indexOf(
      '/// Standalone compile-only smoke app',
      nutritionPhaseStart,
    );
    final nutritionPhase = source.substring(
      nutritionPhaseStart,
      nutritionPhaseEnd,
    );
    final profileReplacement = nutritionPhase.indexOf(
      'app.editPage(ff.Pages.orionProfilePage',
    );
    final reappliedVisibility = nutritionPhase.indexOf(
      '_applyHorseDetailResponsiveVisibility(app);',
    );
    expect(profileReplacement, greaterThanOrEqualTo(0));
    expect(reappliedVisibility, greaterThan(profileReplacement));
  });

  test('effective feeding resolver contract covers inclusive overrides', () {
    String resolveSource({
      required DateTime date,
      required String roundId,
      DateTime? start,
      DateTime? end,
      Set<String> temporaryRounds = const {},
      bool intentionallyEmpty = false,
    }) {
      final day = DateTime(date.year, date.month, date.day);
      final rangeStart =
          start == null ? null : DateTime(start.year, start.month, start.day);
      final rangeEnd =
          end == null ? null : DateTime(end.year, end.month, end.day);
      final active =
          rangeStart != null &&
          rangeEnd != null &&
          !day.isBefore(rangeStart) &&
          !day.isAfter(rangeEnd) &&
          temporaryRounds.contains(roundId);
      if (!active) return 'standard';
      return intentionallyEmpty ? 'temporary-empty' : 'temporary';
    }

    final first = DateTime(2026, 8, 1);
    final finalDay = DateTime(2026, 8, 5);
    expect(
      resolveSource(date: DateTime(2026, 7, 31), roundId: 'morning'),
      'standard',
    );
    expect(
      resolveSource(
        date: first,
        roundId: 'morning',
        start: first,
        end: finalDay,
        temporaryRounds: {'morning'},
      ),
      'temporary',
    );
    expect(
      resolveSource(
        date: finalDay,
        roundId: 'morning',
        start: first,
        end: finalDay,
        temporaryRounds: {'morning'},
      ),
      'temporary',
    );
    expect(
      resolveSource(
        date: DateTime(2026, 8, 6),
        roundId: 'morning',
        start: first,
        end: finalDay,
        temporaryRounds: {'morning'},
      ),
      'standard',
    );
    expect(
      resolveSource(
        date: DateTime(2026, 8, 3),
        roundId: 'evening',
        start: first,
        end: finalDay,
        temporaryRounds: {'morning'},
      ),
      'standard',
    );
    expect(
      resolveSource(
        date: DateTime(2026, 8, 3),
        roundId: 'morning',
        start: first,
        end: finalDay,
        temporaryRounds: {'morning'},
        intentionallyEmpty: true,
      ),
      'temporary-empty',
    );

    final source = File('dsl/edit.dart').readAsStringSync();
    final resolverStart = source.indexOf(
      "app.customFunction(\n    'resolveEffectiveFeedingScheduleV1'",
    );
    final resolverEnd = source.indexOf('  app.raw((project) {', resolverStart);
    final generatedResolver = source.substring(resolverStart, resolverEnd);
    expect(
      generatedResolver,
      contains('!targetDate.isBefore(start) && !targetDate.isAfter(end)'),
    );
    expect(generatedResolver, contains("sourceType: 'temporary'"));
    expect(generatedResolver, contains("sourceType: 'standard'"));
    expect(generatedResolver, contains('if (snapshot == null) continue;'));
    expect(generatedResolver, contains('snapshot.items'));
    expect(generatedResolver, contains("temporaryScheduleId: schedule.id"));
  });

  test('temporary feeding schedules detect round-specific overlap', () {
    bool conflicts({
      required DateTime firstStart,
      required DateTime firstEnd,
      required Set<String> firstRounds,
      required DateTime secondStart,
      required DateTime secondEnd,
      required Set<String> secondRounds,
    }) {
      final datesOverlap =
          !firstEnd.isBefore(secondStart) && !firstStart.isAfter(secondEnd);
      final roundsOverlap = firstRounds.any(secondRounds.contains);
      return datesOverlap && roundsOverlap;
    }

    expect(
      conflicts(
        firstStart: DateTime(2026, 8, 1),
        firstEnd: DateTime(2026, 8, 5),
        firstRounds: {'morning'},
        secondStart: DateTime(2026, 8, 3),
        secondEnd: DateTime(2026, 8, 7),
        secondRounds: {'evening'},
      ),
      isFalse,
    );
    expect(
      conflicts(
        firstStart: DateTime(2026, 8, 1),
        firstEnd: DateTime(2026, 8, 5),
        firstRounds: {'morning'},
        secondStart: DateTime(2026, 8, 5),
        secondEnd: DateTime(2026, 8, 7),
        secondRounds: {'morning', 'evening'},
      ),
      isTrue,
    );

    final source = File('dsl/edit.dart').readAsStringSync();
    expect(source, contains('if (schedule.id == widget.existing?.id)'));
    expect(source, contains('final shared = _selectedRounds'));
    expect(source, contains('Overlapping:'));
    expect(
      source,
      allOf(
        contains("'Voor deze ronde staat tijdelijk geen voeding '"),
        contains("'ingesteld. Weet je zeker dat dit klopt?'"),
      ),
    );
  });

  test('daily feeding schema remains additive and stable scoped', () {
    final schemas =
        File('lib/flutterflow_project/schemas.dart').readAsStringSync();
    final appState =
        File('lib/flutterflow_project/app_state.dart').readAsStringSync();

    for (final structName in const [
      'FeedingRoundConfigData',
      'FeedingAssignmentExceptionData',
      'ResolvedFeedingResponsibleData',
      'FeedingExecutionRecordData',
    ]) {
      expect(schemas, contains('"$structName"'));
    }
    for (final field in const [
      '"stableId": ffai.string',
      '"roundId": ffai.string',
      '"plannedTime": ffai.dateTime',
      '"defaultResponsibleUserId": ffai.string',
      '"replacementResponsibleUserId": ffai.string',
      '"explicitlyUnassigned": ffai.bool_',
      '"performedByUserId": ffai.string',
      '"scheduleItems": ffai.listOf(Structs.feedingItemData)',
      '"temporaryScheduleId": ffai.string',
      '"isReopened": ffai.bool_',
    ]) {
      expect(schemas, contains(field));
    }
    for (final stateName in const [
      'feedingRoundConfigs',
      'feedingAssignmentExceptions',
      'feedingExecutionRecords',
      'nextFeedingAssignmentExceptionId',
      'nextFeedingExecutionRecordId',
      'selectedFeedingDateKey',
      'selectedFeedingRoundId',
    ]) {
      expect(appState, contains('static const $stateName'));
    }
  });

  test('feeding responsibility resolver prefers local-date exceptions', () {
    final resolver =
        File(
          'generated_code/lib/custom_code/functions/'
          'resolve_feeding_responsible_user_v1.dart',
        ).readAsStringSync();
    expect(resolver, contains('sameDay(item.date)'));
    expect(resolver, contains('exception.explicitlyUnassigned'));
    expect(resolver, contains("source: resolved.isEmpty ? 'unassigned'"));
    expect(resolver, contains("source: defaultUserId.isEmpty ? 'unassigned'"));
    expect(
      resolver.indexOf('if (matchingExceptions.isNotEmpty)'),
      lessThan(resolver.indexOf('FeedingRoundConfigDataStruct? config')),
    );
  });

  test('feed-room execution is deduplicated and snapshots the served plan', () {
    final runtime =
        File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
    final source = File('dsl/edit.dart').readAsStringSync();

    expect(runtime, contains('feedingExecutionLogicalKeyV1('));
    expect(runtime, contains('_pendingRecordKeys.contains(key)'));
    expect(runtime, contains('if (existing != null && !existing.isReopened)'));
    expect(
      runtime,
      contains('scheduleItems: state.schedule.items.map(_feedingCopyItem)'),
    );
    expect(runtime, contains("status: 'deviation'"));
    expect(runtime, contains("'Ongedaan maken'"));
    expect(runtime, contains("'Resultaat heropenen?'"));
    expect(runtime, contains("displaySource == 'temporary'"));
    expect(runtime, contains("'Voerschema ontbreekt'"));
    expect(runtime, contains("'Tijdelijk geen voeding'"));
    expect(runtime, contains('bool get _canExecute => _isToday;'));
    expect(source, contains("route: '/voeding'"));
    expect(source, contains("route: '/voeding/ronde'"));
    expect(source, contains("route: '/voeding/instellingen'"));
    expect(source, contains("widgets.byKey('Column_r646vnfd').single"));
    expect(source, contains("widgets.byKey('Column_5iv3rs34').single"));
  });

  test('daily feeding runtime uses one responsive AVARYN implementation', () {
    final runtime =
        File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
    final source = File('dsl/edit.dart').readAsStringSync();
    expect(runtime, contains("'today' => _buildTodayCard(context)"));
    expect(runtime, contains("'execution' => _buildExecution(context)"));
    expect(runtime, contains("'settings' => _buildSettings(context)"));
    expect(runtime, contains('SingleChildScrollView('));
    expect(runtime, contains('ConstrainedBox('));
    expect(runtime, contains('ListWheelScrollView.useDelegate'));
    expect(runtime, contains('controller.jumpToItem(index)'));
    expect(runtime, contains('theme.bodySmall.copyWith(color: theme.error)'));
    expect(runtime, contains("'Huidige lokaal geregistreerde gebruiker'"));
    expect(runtime, contains("'Nog niemand toegewezen'"));
    expect(
      source,
      contains("? \"import '/app_state.dart';\""),
      reason:
          'The deployed daily feeding widget must import the current FFAppState directly.',
    );
    expect(
      source,
      contains("import '/app_state.dart';"),
      reason:
          'The horse nutrition widget must import the current FFAppState directly.',
    );
    expect(runtime, isNot(contains('showTimePicker')));
    expect(runtime, isNot(contains('showDatePicker')));
  });

  test('phase 3 progress uses one bounded calculation on every surface', () {
    ({int applicable, int processed, int deviations, int missing, int empty})
    calculate(
      List<
        ({
          bool hasPlan,
          bool hasItems,
          bool processed,
          bool hasSnapshot,
          bool deviation,
        })
      >
      states,
    ) {
      var applicable = 0;
      var processed = 0;
      var deviations = 0;
      var missing = 0;
      var empty = 0;
      for (final state in states) {
        final actionable =
            state.hasPlan &&
            (state.hasItems || (state.processed && state.hasSnapshot));
        if (actionable) applicable += 1;
        if (actionable && state.processed) processed += 1;
        if (actionable && state.processed && state.deviation) deviations += 1;
        if (!state.hasPlan) missing += 1;
        if (state.hasPlan && !actionable && !state.processed) empty += 1;
      }
      if (processed > applicable) processed = applicable;
      return (
        applicable: applicable,
        processed: processed,
        deviations: deviations,
        missing: missing,
        empty: empty,
      );
    }

    final progress = calculate([
      (
        hasPlan: true,
        hasItems: true,
        processed: false,
        hasSnapshot: false,
        deviation: false,
      ),
      (
        hasPlan: true,
        hasItems: false,
        processed: true,
        hasSnapshot: true,
        deviation: false,
      ),
      (
        hasPlan: true,
        hasItems: true,
        processed: true,
        hasSnapshot: true,
        deviation: true,
      ),
      (
        hasPlan: true,
        hasItems: false,
        processed: false,
        hasSnapshot: false,
        deviation: false,
      ),
      (
        hasPlan: false,
        hasItems: false,
        processed: false,
        hasSnapshot: false,
        deviation: false,
      ),
    ]);
    expect(progress.applicable, 3);
    expect(progress.processed, 2);
    expect(progress.applicable - progress.processed, 1);
    expect(progress.deviations, 1);
    expect(progress.missing, 1);
    expect(progress.empty, 1);

    final runtime =
        File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
    expect(runtime, contains('class _FeedingProgress'));
    expect(runtime, contains('_FeedingProgress _progressFor'));
    expect(
      RegExp(r'_progressFor\(states\)').allMatches(runtime).length,
      greaterThanOrEqualTo(3),
    );
    expect(runtime, contains('(processed / applicable).clamp(0.0, 1.0)'));
    expect(runtime, contains('bool get isComplete => open == 0'));
  });

  test(
    'phase 3 keeps one logical execution result and immutable display data',
    () {
      final runtime =
          File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();

      expect(runtime, contains('bool _feedingSameLogicalRecord('));
      expect(runtime, contains('all.removeWhere('));
      expect(runtime, contains('all.add(record);'));
      expect(runtime, contains('all.add(reopened);'));
      expect(
        runtime,
        contains(
          'isProcessed && hasSavedSnapshot ? record!.scheduleItems : schedule.items',
        ),
      );
      expect(runtime, contains("'OPGESLAGEN VOERSNAPSHOT'"));
      expect(runtime, contains("'Historisch resultaat · heropend'"));
      expect(runtime, contains('performedByUserId: latest.performedByUserId'));
      expect(
        runtime,
        contains('scheduleItems: latest.scheduleItems.map(_feedingCopyItem)'),
      );
    },
  );

  test('phase 3 stable scoping keeps legacy data in its own stable', () {
    String scopedStable(String storedStableId) =>
        storedStableId.trim().isEmpty ? 'local-stable' : storedStableId.trim();

    expect(scopedStable(''), 'local-stable');
    expect(scopedStable('stable-a'), 'stable-a');
    expect(scopedStable('') == 'stable-b', isFalse);
    expect(scopedStable('stable-a') == 'stable-b', isFalse);

    final runtime =
        File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
    final nutrition = File('dsl/edit.dart').readAsStringSync();
    expect(runtime, contains("const _feedingLegacyStableId = 'local-stable'"));
    expect(runtime, contains('return scopedStable == _stableId;'));
    expect(
      nutrition,
      contains(
        'item.stableId == _stableId &&\n'
        '            item.horseId == _horse.id',
      ),
    );
    expect(
      nutrition,
      contains('item.horseId == _horse.id && item.stableId == _stableId'),
    );
  });

  test(
    'phase 3 local dates are normalized and future execution stays blocked',
    () {
      DateTime day(DateTime value) =>
          DateTime(value.year, value.month, value.day);
      DateTime shift(DateTime value, int days) =>
          DateTime(value.year, value.month, value.day + days);

      final sourceDay = DateTime(2026, 10, 25, 23, 45);
      expect(day(sourceDay), DateTime(2026, 10, 25));
      expect(shift(sourceDay, 1), DateTime(2026, 10, 26));
      expect(shift(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));

      final runtime =
          File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
      expect(
        runtime,
        contains('DateTime(value.year, value.month, value.day + days)'),
      );
      expect(runtime, contains('bool get _canExecute => _isToday;'));
      expect(runtime, contains('feedingDate: _feedingDay(_selectedDate)'));
      expect(runtime, contains('_feedingSameDay(record.feedingDate, date)'));
    },
  );

  test(
    'phase 3 old temporary data and future custom rounds remain additive',
    () {
      final source = File('dsl/edit.dart').readAsStringSync();
      expect(source, contains('final preservedCustomRounds ='));
      expect(source, contains('...preservedCustomRounds'));
      expect(source, contains('if (snapshot == null) continue;'));
      expect(
        source,
        contains('_rounds[roundId] = _nutritionCopyRound(standard);'),
      );
      expect(
        source,
        contains(
          'orElse:\n'
          '            () => FeedingRoundSnapshotDataStruct(\n'
          '              roundId: roundId,\n'
          '              items: const <FeedingItemDataStruct>[],',
        ),
      );
    },
  );

  test(
    'phase 3 responsibility resolution is newest-first and history-safe',
    () {
      final source = File('dsl/edit.dart').readAsStringSync();
      final runtime =
          File('dsl/avaryn_daily_feeding_runtime.dart').readAsStringSync();
      expect(source, contains('final matchingExceptions ='));
      expect(source, contains('final matchingConfigs ='));
      expect(
        RegExp(r'\.\.sort\(').allMatches(source).length,
        greaterThanOrEqualTo(2),
      );
      expect(
        runtime,
        contains('resolvedResponsibleUserId: responsible.resolvedUserId'),
      );
      expect(runtime, contains('performedByUserId: latest.performedByUserId'));
      expect(
        runtime,
        contains('resolvedResponsibleUserId: latest.resolvedResponsibleUserId'),
      );
      expect(
        runtime,
        contains(
          'item.stableId == _stableId &&\n'
          '          item.roundId == roundId &&\n'
          '          _feedingSameDay(item.date, _selectedDate)',
        ),
      );
    },
  );

  test('phase 4A auth, onboarding and profile boundary is complete', () {
    final source = File('dsl/edit.dart').readAsStringSync();
    final runtime = File('dsl/avaryn_account_runtime.dart').readAsStringSync();
    final schemas =
        File('lib/flutterflow_project/schemas.dart').readAsStringSync();

    expect(source, contains('const bool _phase4ASchemaCheckpointOnly = false'));
    expect(schemas, contains('"AvarynAccountRuntime"'));

    for (final pageFile in const [
      'auth_gate_page.dart',
      'auth_welcome_page.dart',
      'auth_email_page.dart',
      'auth_create_account_page.dart',
      'auth_login_page.dart',
      'auth_verify_email_page.dart',
      'auth_forgot_password_page.dart',
      'auth_reset_password_page.dart',
      'auth_callback_page.dart',
      'onboarding_page.dart',
      'personal_profile_page.dart',
    ]) {
      expect(
        File('lib/flutterflow_project/pages/$pageFile').existsSync(),
        isTrue,
        reason: '$pageFile must be present in the completed Phase 4A flow',
      );
    }

    for (final contract in const [
      'Supabase.instance.client',
      'signInWithPassword',
      'auth.signUp',
      'auth.resend',
      'resetPasswordForEmail',
      'AuthChangeEvent.passwordRecovery',
      'auth.updateUser',
      'auth.signOut',
      "from('profiles')",
      "onConflict: 'id'",
      'activeAuthAccountId',
      'localAccountScopes',
      'Doorgaan met Apple',
      'Doorgaan met Google',
      'Doorgaan met e-mail',
      '_cooldownSeconds = 60',
      "'initials' => _accountInitials()",
      "'greeting' => _accountGreeting(compact: false)",
    ]) {
      expect(
        runtime,
        contains(contract),
        reason: 'Missing contract: $contract',
      );
    }

    expect(runtime, contains("context.goNamed('AuthWelcomePage')"));
    expect(runtime, contains("context.goNamed('AuthGatePage')"));
    expect(runtime, contains("context.goNamed('OnboardingPage')"));
    expect(runtime, contains("context.goNamed('TodayDashboardPage')"));
    expect(runtime, isNot(contains('SupabaseClient(')));
    expect(source, contains("'AuthenticatedDesktopAccountGreeting'"));
    expect(source, contains("'AuthenticatedMobileAccountGreeting'"));
    expect(source, contains("profileTarget: 'PersonalProfilePage'"));
  });
}
