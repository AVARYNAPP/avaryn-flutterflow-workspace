import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'horses_overview_page_model.dart';
export 'horses_overview_page_model.dart';

/// AVARYN Alpha product route backed by the existing RLS-scoped Phase 4/5
/// contracts.
class HorsesOverviewPageWidget extends StatefulWidget {
  const HorsesOverviewPageWidget({super.key});

  static String routeName = 'HorsesOverviewPage';
  static String routePath = '/paarden';

  @override
  State<HorsesOverviewPageWidget> createState() =>
      _HorsesOverviewPageWidgetState();
}

class _HorsesOverviewPageWidgetState extends State<HorsesOverviewPageWidget> {
  late HorsesOverviewPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HorsesOverviewPageModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (FFAppState().horseSeedVersion == 0) {
        FFAppState().addToHorses(HorseProfileDataStruct(
          id: 1,
          officialName: 'North Star',
          callName: 'Orion',
          photoData: 'samplePhoto',
          discipline: 'Dressuur',
          competitionClass: 'Grand Prix',
          birthDate: functions.parseHorsePrototypeDate('2015-04-17'),
          sex: 'Ruin',
          breed: 'KWPN',
          color: 'Donkerbruin',
          passportNumber: '528003201508742',
          passportExpiryDate: functions.parseHorsePrototypeDate('2026-11-30'),
          chipNumber: '528210004982315',
          owner: 'Sophie de Ruiter',
          rider: 'Sophie de Ruiter',
          stableLocation: 'AVARYN Performance Stables',
          notes:
              'Gevoelig, werkwillig en het meest ontspannen met een rustige opbouw.',
          dayForm: '86%',
          attention: 'Verhoogde warmte linker voorbeen',
          nextActivity: '10:30 · Dressuurtraining en piaffe-passages',
        ));
        safeSetState(() {});
        FFAppState().addToHorses(HorseProfileDataStruct(
          id: 2,
          officialName: 'Celestial Rhythm',
          callName: 'Celeste',
          photoData: '',
          discipline: 'Dressuur',
          competitionClass: 'Intermediaire I',
          birthDate: functions.parseHorsePrototypeDate('2017-06-02'),
          sex: 'Merrie',
          breed: 'Hannoveraan',
          color: 'Vos',
          passportNumber: 'DE431316784517',
          passportExpiryDate: functions.parseHorsePrototypeDate('2027-06-30'),
          chipNumber: '276020000431682',
          owner: 'AVARYN Sport Horses',
          rider: 'Sophie de Ruiter',
          stableLocation: 'AVARYN Performance Stables',
          notes: 'Expressieve merrie met veel aanleg voor verzameling.',
          dayForm: '78%',
          attention: 'Hydratatie na transport volgen',
          nextActivity: '13:15 · Buitenstap en herstel',
        ));
        safeSetState(() {});
        FFAppState().addToHorses(HorseProfileDataStruct(
          id: 3,
          officialName: 'Vesper Noir',
          callName: 'Vesper',
          photoData: '',
          discipline: 'Dressuur',
          competitionClass: 'Prix St. Georges',
          birthDate: functions.parseHorsePrototypeDate('2016-03-11'),
          sex: 'Ruin',
          breed: 'Oldenburger',
          color: 'Zwart',
          passportNumber: 'DE433330921516',
          passportExpiryDate: functions.parseHorsePrototypeDate('2026-07-22'),
          chipNumber: '276098106773412',
          owner: 'Sophie de Ruiter',
          rider: 'Mila Vos',
          stableLocation: 'AVARYN Performance Stables',
          notes: 'Atletisch en scherp; reageert goed op een lage warming-up.',
          dayForm: '92%',
          attention: 'Rustige, lage warming-up',
          nextActivity: '16:00 · Cavaletti en souplesse',
        ));
        safeSetState(() {});
        FFAppState().selectedHorse = HorseProfileDataStruct(
          id: 1,
          officialName: 'North Star',
          callName: 'Orion',
          photoData: 'samplePhoto',
          discipline: 'Dressuur',
          competitionClass: 'Grand Prix',
          birthDate: functions.parseHorsePrototypeDate('2015-04-17'),
          sex: 'Ruin',
          breed: 'KWPN',
          color: 'Donkerbruin',
          passportNumber: '528003201508742',
          passportExpiryDate: functions.parseHorsePrototypeDate('2026-11-30'),
          chipNumber: '528210004982315',
          owner: 'Sophie de Ruiter',
          rider: 'Sophie de Ruiter',
          stableLocation: 'AVARYN Performance Stables',
          notes:
              'Gevoelig, werkwillig en het meest ontspannen met een rustige opbouw.',
          dayForm: '86%',
          attention: 'Verhoogde warmte linker voorbeen',
          nextActivity: '10:30 · Dressuurtraining en piaffe-passages',
        );
        safeSetState(() {});
        FFAppState().selectedHorseIndex = 0;
        safeSetState(() {});
        FFAppState().nextHorseId = 4;
        safeSetState(() {});
        FFAppState().nextHorseIndex = 3;
        safeSetState(() {});
        FFAppState().horseSeedVersion = 1;
        safeSetState(() {});
        if (FFAppState().passportPrototypeVersion == 0) {
          FFAppState().selectedHorseIndex = 0;
          safeSetState(() {});
          FFAppState().updateHorsesAtIndex(
            FFAppState().selectedHorseIndex,
            (_) => HorseProfileDataStruct(
              id: 1,
              officialName: 'North Star',
              callName: 'Orion',
              photoData: 'samplePhoto',
              discipline: 'Dressuur',
              competitionClass: 'Grand Prix',
              birthDate: functions.parseHorsePrototypeDate('2015-04-17'),
              sex: 'Ruin',
              breed: 'KWPN',
              color: 'Donkerbruin',
              passportNumber: '528003201508742',
              passportExpiryDate:
                  functions.parseHorsePrototypeDate('2026-11-30'),
              chipNumber: '528210004982315',
              owner: 'Sophie de Ruiter',
              rider: 'Sophie de Ruiter',
              stableLocation: 'AVARYN Performance Stables',
              notes:
                  'Gevoelig, werkwillig en het meest ontspannen met een rustige opbouw.',
              dayForm: '86%',
              attention: 'Verhoogde warmte linker voorbeen',
              nextActivity: '10:30 · Dressuurtraining en piaffe-passages',
            ),
          );
          safeSetState(() {});
          FFAppState().selectedHorseIndex = 1;
          safeSetState(() {});
          FFAppState().updateHorsesAtIndex(
            FFAppState().selectedHorseIndex,
            (_) => HorseProfileDataStruct(
              id: 2,
              officialName: 'Celestial Rhythm',
              callName: 'Celeste',
              photoData: '',
              discipline: 'Dressuur',
              competitionClass: 'Intermediaire I',
              birthDate: functions.parseHorsePrototypeDate('2017-06-02'),
              sex: 'Merrie',
              breed: 'Hannoveraan',
              color: 'Vos',
              passportNumber: 'DE431316784517',
              passportExpiryDate:
                  functions.parseHorsePrototypeDate('2027-06-30'),
              chipNumber: '276020000431682',
              owner: 'AVARYN Sport Horses',
              rider: 'Sophie de Ruiter',
              stableLocation: 'AVARYN Performance Stables',
              notes: 'Expressieve merrie met veel aanleg voor verzameling.',
              dayForm: '78%',
              attention: 'Hydratatie na transport volgen',
              nextActivity: '13:15 · Buitenstap en herstel',
            ),
          );
          safeSetState(() {});
          FFAppState().selectedHorseIndex = 2;
          safeSetState(() {});
          FFAppState().updateHorsesAtIndex(
            FFAppState().selectedHorseIndex,
            (_) => HorseProfileDataStruct(
              id: 3,
              officialName: 'Vesper Noir',
              callName: 'Vesper',
              photoData: '',
              discipline: 'Dressuur',
              competitionClass: 'Prix St. Georges',
              birthDate: functions.parseHorsePrototypeDate('2016-03-11'),
              sex: 'Ruin',
              breed: 'Oldenburger',
              color: 'Zwart',
              passportNumber: 'DE433330921516',
              passportExpiryDate:
                  functions.parseHorsePrototypeDate('2026-07-22'),
              chipNumber: '276098106773412',
              owner: 'Sophie de Ruiter',
              rider: 'Mila Vos',
              stableLocation: 'AVARYN Performance Stables',
              notes:
                  'Atletisch en scherp; reageert goed op een lage warming-up.',
              dayForm: '92%',
              attention: 'Rustige, lage warming-up',
              nextActivity: '16:00 · Cavaletti en souplesse',
            ),
          );
          safeSetState(() {});
          FFAppState().selectedHorse = HorseProfileDataStruct(
            id: 1,
            officialName: 'North Star',
            callName: 'Orion',
            photoData: 'samplePhoto',
            discipline: 'Dressuur',
            competitionClass: 'Grand Prix',
            birthDate: functions.parseHorsePrototypeDate('2015-04-17'),
            sex: 'Ruin',
            breed: 'KWPN',
            color: 'Donkerbruin',
            passportNumber: '528003201508742',
            passportExpiryDate: functions.parseHorsePrototypeDate('2026-11-30'),
            chipNumber: '528210004982315',
            owner: 'Sophie de Ruiter',
            rider: 'Sophie de Ruiter',
            stableLocation: 'AVARYN Performance Stables',
            notes:
                'Gevoelig, werkwillig en het meest ontspannen met een rustige opbouw.',
            dayForm: '86%',
            attention: 'Verhoogde warmte linker voorbeen',
            nextActivity: '10:30 · Dressuurtraining en piaffe-passages',
          );
          safeSetState(() {});
          FFAppState().selectedHorseIndex = 0;
          safeSetState(() {});
          FFAppState().passportPrototypeVersion = 1;
          safeSetState(() {});
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (responsiveVisibility(
                context: context,
                phone: false,
                tablet: false,
                tabletLandscape: false,
              ))
                Container(
                  child: Container(
                    width: 232.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(18.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 12.0, 8.0, 12.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AVARYN',
                                    style: FlutterFlowTheme.of(context)
                                        .titleLarge
                                        .override(
                                          font: GoogleFonts.interTight(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleLarge
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleLarge
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .accent1,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  Text(
                                    'Performance',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                  ),
                                ].divide(SizedBox(height: 2.0)),
                              ),
                            ),
                          ),
                          Container(
                            height: 1.0,
                            decoration: BoxDecoration(
                              color: Color(0xFF343532),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).primary,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2.0,
                                  height: 30.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    borderRadius: BorderRadius.circular(999.0),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      context.pushNamed(
                                          TodayDashboardPageWidget.routeName);
                                    },
                                    text: 'Vandaag',
                                    icon: Icon(
                                      Icons.today,
                                      size: 20.0,
                                    ),
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 48.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor:
                                          FlutterFlowTheme.of(context).tertiary,
                                      color: Colors.transparent,
                                      textStyle: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .tertiary,
                                      ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Paarden is al geselecteerd',
                                    style: TextStyle(),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Color(0xFF292529),
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 2.0,
                                    height: 30.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .secondary,
                                      borderRadius:
                                          BorderRadius.circular(999.0),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Container(
                                      height: 48.0,
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 20.0,
                                              height: 20.0,
                                              child: Container(
                                                child: custom_widgets
                                                    .AvarynHorseshoeIcon(
                                                  active: true,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Paarden',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .accent1,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                          ].divide(SizedBox(width: 12.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).primary,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2.0,
                                  height: 30.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    borderRadius: BorderRadius.circular(999.0),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      context.pushNamed(
                                          FeedingOverviewPageWidget.routeName);
                                    },
                                    text: 'Voeding',
                                    icon: Icon(
                                      Icons.restaurant_menu,
                                      size: 20.0,
                                    ),
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 48.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor:
                                          FlutterFlowTheme.of(context).tertiary,
                                      color: Colors.transparent,
                                      textStyle: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .tertiary,
                                      ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).primary,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2.0,
                                  height: 30.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    borderRadius: BorderRadius.circular(999.0),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    },
                                    text: 'Planning',
                                    icon: Icon(
                                      Icons.event_note,
                                      size: 20.0,
                                    ),
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 48.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor:
                                          FlutterFlowTheme.of(context).tertiary,
                                      color: Colors.transparent,
                                      textStyle: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .tertiary,
                                      ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).primary,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 2.0,
                                  height: 30.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    borderRadius: BorderRadius.circular(999.0),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: FFButtonWidget(
                                    onPressed: () async {
                                      context.pushNamed(
                                          PersonalProfilePageWidget.routeName);
                                    },
                                    text: 'Profiel',
                                    icon: Icon(
                                      Icons.person,
                                      size: 20.0,
                                    ),
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 48.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 0.0, 0.0, 0.0),
                                      iconPadding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 0.0, 0.0, 0.0),
                                      iconColor:
                                          FlutterFlowTheme.of(context).tertiary,
                                      color: Colors.transparent,
                                      textStyle: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .tertiary,
                                      ),
                                      elevation: 0.0,
                                      borderRadius: BorderRadius.circular(10.0),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Spacer(),
                          Container(
                            child: Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_done,
                                    color: Color(0xFF8E8F8B),
                                    size: 17.0,
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Besloten Alpha',
                                          style: FlutterFlowTheme.of(context)
                                              .labelSmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelSmall
                                                          .fontStyle,
                                                ),
                                                color: Color(0xFFD8D4CE),
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                        Text(
                                          'Geen productie',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                color: Color(0xFF8E8F8B),
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                        ),
                                      ].divide(SizedBox(height: 1.0)),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 9.0)),
                              ),
                            ),
                          ),
                        ].divide(SizedBox(height: 8.0)),
                      ),
                    ),
                  ),
                ),
              Expanded(
                flex: 1,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 78.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              18.0, 8.0, 18.0, 8.0),
                          child: Container(
                            child: custom_widgets.AvarynStableRuntime(
                              mode: 'selector',
                              initialStableMemberId: '',
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Container(
                          child: custom_widgets.AvarynOperationalRuntime(
                            mode: 'horses',
                          ),
                        ),
                      ),
                      if (responsiveVisibility(
                        context: context,
                        desktop: false,
                      ))
                        Container(
                          child: Container(
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).accent4,
                              boxShadow: [
                                BoxShadow(
                                  blurRadius: 24.0,
                                  color: Color(0x24171518),
                                  offset: Offset(
                                    0.0,
                                    -8.0,
                                  ),
                                  spreadRadius: -10.0,
                                )
                              ],
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 0.6,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  6.0, 8.0, 6.0, 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          TodayDashboardPageWidget.routeName);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accent4,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            3.0, 2.0, 3.0, 2.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 22.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent4,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999.0),
                                              ),
                                            ),
                                            Icon(
                                              Icons.home,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 19.0,
                                            ),
                                            Text(
                                              'Vandaag',
                                              maxLines: 1,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Paarden is al geselecteerd',
                                            style: TextStyle(),
                                          ),
                                          duration:
                                              Duration(milliseconds: 4000),
                                        ),
                                      );
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accent4,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            3.0, 2.0, 3.0, 2.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 22.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondary,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999.0),
                                              ),
                                            ),
                                            Container(
                                              width: 19.0,
                                              height: 19.0,
                                              child: Container(
                                                child: custom_widgets
                                                    .AvarynHorseshoeIcon(
                                                  active: true,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              'Paarden',
                                              maxLines: 1,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondary,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          FeedingOverviewPageWidget.routeName);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accent4,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            3.0, 2.0, 3.0, 2.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 22.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent4,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999.0),
                                              ),
                                            ),
                                            Icon(
                                              Icons.restaurant_menu,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 19.0,
                                            ),
                                            Text(
                                              'Voeding',
                                              maxLines: 1,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          PlanningPageWidget.routeName);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accent4,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            3.0, 2.0, 3.0, 2.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 22.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent4,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999.0),
                                              ),
                                            ),
                                            Icon(
                                              Icons.event_note,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 19.0,
                                            ),
                                            Text(
                                              'Planning',
                                              maxLines: 1,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context.pushNamed(
                                          PersonalProfilePageWidget.routeName);
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .accent4,
                                        borderRadius:
                                            BorderRadius.circular(6.0),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            3.0, 2.0, 3.0, 2.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 22.0,
                                              height: 2.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .accent4,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        999.0),
                                              ),
                                            ),
                                            Icon(
                                              Icons.person,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 19.0,
                                            ),
                                            Text(
                                              'Profiel',
                                              maxLines: 1,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
