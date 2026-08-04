// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// One shared local prototype activity model used by Planning and Vandaag.
class ActivityDataStruct extends BaseStruct {
  ActivityDataStruct({
    /// ActivityData.id
    int? id,

    /// ActivityData.activityType
    String? activityType,

    /// ActivityData.horseId
    int? horseId,

    /// ActivityData.title
    String? title,

    /// ActivityData.date
    DateTime? date,

    /// ActivityData.time
    DateTime? time,

    /// ActivityData.notes
    String? notes,

    /// ActivityData.isCompleted
    bool? isCompleted,

    /// ActivityData.createdAt
    DateTime? createdAt,

    /// ActivityData.updatedAt
    DateTime? updatedAt,

    /// Stable identifier when a stable context is available.
    String? stableId,

    /// User-entered title used only for the Overig activity type.
    String? customTitle,

    /// Stable user identifiers assigned to this activity.
    List<String>? assigneeUserIds,

    /// Typed local start date for scheduling and agenda display.
    DateTime? startDate,

    /// Optional typed local end date for multi-day activities.
    DateTime? endDate,

    /// Optional typed local start time.
    DateTime? startTime,

    /// Optional typed local end time.
    DateTime? endTime,

    /// Whether the activity occupies its selected calendar day or range.
    bool? allDay,

    /// Optional duration used by care activities and schedule calculations.
    int? durationMinutes,

    /// Semantic location choice such as Op stal or Op locatie.
    String? locationType,

    /// Optional external location or competition venue.
    String? locationName,

    /// Optional farrier or veterinarian name.
    String? serviceProviderName,

    /// Completion state stored independently from the legacy boolean field.
    String? completionStatus,
  })  : _id = id,
        _activityType = activityType,
        _horseId = horseId,
        _title = title,
        _date = date,
        _time = time,
        _notes = notes,
        _isCompleted = isCompleted,
        _createdAt = createdAt,
        _updatedAt = updatedAt,
        _stableId = stableId,
        _customTitle = customTitle,
        _assigneeUserIds = assigneeUserIds,
        _startDate = startDate,
        _endDate = endDate,
        _startTime = startTime,
        _endTime = endTime,
        _allDay = allDay,
        _durationMinutes = durationMinutes,
        _locationType = locationType,
        _locationName = locationName,
        _serviceProviderName = serviceProviderName,
        _completionStatus = completionStatus;

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "activityType" field.
  String? _activityType;
  String get activityType => _activityType ?? '';
  set activityType(String? val) => _activityType = val;

  bool hasActivityType() => _activityType != null;

  // "horseId" field.
  int? _horseId;
  int get horseId => _horseId ?? 0;
  set horseId(int? val) => _horseId = val;

  void incrementHorseId(int amount) => horseId = horseId + amount;

  bool hasHorseId() => _horseId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  set title(String? val) => _title = val;

  bool hasTitle() => _title != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  set date(DateTime? val) => _date = val;

  bool hasDate() => _date != null;

  // "time" field.
  DateTime? _time;
  DateTime? get time => _time;
  set time(DateTime? val) => _time = val;

  bool hasTime() => _time != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  set notes(String? val) => _notes = val;

  bool hasNotes() => _notes != null;

  // "isCompleted" field.
  bool? _isCompleted;
  bool get isCompleted => _isCompleted ?? false;
  set isCompleted(bool? val) => _isCompleted = val;

  bool hasIsCompleted() => _isCompleted != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  set createdAt(DateTime? val) => _createdAt = val;

  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? val) => _updatedAt = val;

  bool hasUpdatedAt() => _updatedAt != null;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  // "customTitle" field.
  String? _customTitle;
  String get customTitle => _customTitle ?? '';
  set customTitle(String? val) => _customTitle = val;

  bool hasCustomTitle() => _customTitle != null;

  // "assigneeUserIds" field.
  List<String>? _assigneeUserIds;
  List<String> get assigneeUserIds => _assigneeUserIds ?? const [];
  set assigneeUserIds(List<String>? val) => _assigneeUserIds = val;

  void updateAssigneeUserIds(Function(List<String>) updateFn) {
    updateFn(_assigneeUserIds ??= []);
  }

  bool hasAssigneeUserIds() => _assigneeUserIds != null;

  // "startDate" field.
  DateTime? _startDate;
  DateTime? get startDate => _startDate;
  set startDate(DateTime? val) => _startDate = val;

  bool hasStartDate() => _startDate != null;

  // "endDate" field.
  DateTime? _endDate;
  DateTime? get endDate => _endDate;
  set endDate(DateTime? val) => _endDate = val;

  bool hasEndDate() => _endDate != null;

  // "startTime" field.
  DateTime? _startTime;
  DateTime? get startTime => _startTime;
  set startTime(DateTime? val) => _startTime = val;

  bool hasStartTime() => _startTime != null;

  // "endTime" field.
  DateTime? _endTime;
  DateTime? get endTime => _endTime;
  set endTime(DateTime? val) => _endTime = val;

  bool hasEndTime() => _endTime != null;

  // "allDay" field.
  bool? _allDay;
  bool get allDay => _allDay ?? false;
  set allDay(bool? val) => _allDay = val;

  bool hasAllDay() => _allDay != null;

  // "durationMinutes" field.
  int? _durationMinutes;
  int get durationMinutes => _durationMinutes ?? 0;
  set durationMinutes(int? val) => _durationMinutes = val;

  void incrementDurationMinutes(int amount) =>
      durationMinutes = durationMinutes + amount;

  bool hasDurationMinutes() => _durationMinutes != null;

  // "locationType" field.
  String? _locationType;
  String get locationType => _locationType ?? '';
  set locationType(String? val) => _locationType = val;

  bool hasLocationType() => _locationType != null;

  // "locationName" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  set locationName(String? val) => _locationName = val;

  bool hasLocationName() => _locationName != null;

  // "serviceProviderName" field.
  String? _serviceProviderName;
  String get serviceProviderName => _serviceProviderName ?? '';
  set serviceProviderName(String? val) => _serviceProviderName = val;

  bool hasServiceProviderName() => _serviceProviderName != null;

  // "completionStatus" field.
  String? _completionStatus;
  String get completionStatus => _completionStatus ?? '';
  set completionStatus(String? val) => _completionStatus = val;

  bool hasCompletionStatus() => _completionStatus != null;

  static ActivityDataStruct fromMap(Map<String, dynamic> data) =>
      ActivityDataStruct(
        id: castToType<int>(data['id']),
        activityType: data['activityType'] as String?,
        horseId: castToType<int>(data['horseId']),
        title: data['title'] as String?,
        date: data['date'] as DateTime?,
        time: data['time'] as DateTime?,
        notes: data['notes'] as String?,
        isCompleted: data['isCompleted'] as bool?,
        createdAt: data['createdAt'] as DateTime?,
        updatedAt: data['updatedAt'] as DateTime?,
        stableId: data['stableId'] as String?,
        customTitle: data['customTitle'] as String?,
        assigneeUserIds: getDataList(data['assigneeUserIds']),
        startDate: data['startDate'] as DateTime?,
        endDate: data['endDate'] as DateTime?,
        startTime: data['startTime'] as DateTime?,
        endTime: data['endTime'] as DateTime?,
        allDay: data['allDay'] as bool?,
        durationMinutes: castToType<int>(data['durationMinutes']),
        locationType: data['locationType'] as String?,
        locationName: data['locationName'] as String?,
        serviceProviderName: data['serviceProviderName'] as String?,
        completionStatus: data['completionStatus'] as String?,
      );

  static ActivityDataStruct? maybeFromMap(dynamic data) => data is Map
      ? ActivityDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'activityType': _activityType,
        'horseId': _horseId,
        'title': _title,
        'date': _date,
        'time': _time,
        'notes': _notes,
        'isCompleted': _isCompleted,
        'createdAt': _createdAt,
        'updatedAt': _updatedAt,
        'stableId': _stableId,
        'customTitle': _customTitle,
        'assigneeUserIds': _assigneeUserIds,
        'startDate': _startDate,
        'endDate': _endDate,
        'startTime': _startTime,
        'endTime': _endTime,
        'allDay': _allDay,
        'durationMinutes': _durationMinutes,
        'locationType': _locationType,
        'locationName': _locationName,
        'serviceProviderName': _serviceProviderName,
        'completionStatus': _completionStatus,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'activityType': serializeParam(
          _activityType,
          ParamType.String,
        ),
        'horseId': serializeParam(
          _horseId,
          ParamType.int,
        ),
        'title': serializeParam(
          _title,
          ParamType.String,
        ),
        'date': serializeParam(
          _date,
          ParamType.DateTime,
        ),
        'time': serializeParam(
          _time,
          ParamType.DateTime,
        ),
        'notes': serializeParam(
          _notes,
          ParamType.String,
        ),
        'isCompleted': serializeParam(
          _isCompleted,
          ParamType.bool,
        ),
        'createdAt': serializeParam(
          _createdAt,
          ParamType.DateTime,
        ),
        'updatedAt': serializeParam(
          _updatedAt,
          ParamType.DateTime,
        ),
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
        'customTitle': serializeParam(
          _customTitle,
          ParamType.String,
        ),
        'assigneeUserIds': serializeParam(
          _assigneeUserIds,
          ParamType.String,
          isList: true,
        ),
        'startDate': serializeParam(
          _startDate,
          ParamType.DateTime,
        ),
        'endDate': serializeParam(
          _endDate,
          ParamType.DateTime,
        ),
        'startTime': serializeParam(
          _startTime,
          ParamType.DateTime,
        ),
        'endTime': serializeParam(
          _endTime,
          ParamType.DateTime,
        ),
        'allDay': serializeParam(
          _allDay,
          ParamType.bool,
        ),
        'durationMinutes': serializeParam(
          _durationMinutes,
          ParamType.int,
        ),
        'locationType': serializeParam(
          _locationType,
          ParamType.String,
        ),
        'locationName': serializeParam(
          _locationName,
          ParamType.String,
        ),
        'serviceProviderName': serializeParam(
          _serviceProviderName,
          ParamType.String,
        ),
        'completionStatus': serializeParam(
          _completionStatus,
          ParamType.String,
        ),
      }.withoutNulls;

  static ActivityDataStruct fromSerializableMap(Map<String, dynamic> data) =>
      ActivityDataStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        activityType: deserializeParam(
          data['activityType'],
          ParamType.String,
          false,
        ),
        horseId: deserializeParam(
          data['horseId'],
          ParamType.int,
          false,
        ),
        title: deserializeParam(
          data['title'],
          ParamType.String,
          false,
        ),
        date: deserializeParam(
          data['date'],
          ParamType.DateTime,
          false,
        ),
        time: deserializeParam(
          data['time'],
          ParamType.DateTime,
          false,
        ),
        notes: deserializeParam(
          data['notes'],
          ParamType.String,
          false,
        ),
        isCompleted: deserializeParam(
          data['isCompleted'],
          ParamType.bool,
          false,
        ),
        createdAt: deserializeParam(
          data['createdAt'],
          ParamType.DateTime,
          false,
        ),
        updatedAt: deserializeParam(
          data['updatedAt'],
          ParamType.DateTime,
          false,
        ),
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
        customTitle: deserializeParam(
          data['customTitle'],
          ParamType.String,
          false,
        ),
        assigneeUserIds: deserializeParam<String>(
          data['assigneeUserIds'],
          ParamType.String,
          true,
        ),
        startDate: deserializeParam(
          data['startDate'],
          ParamType.DateTime,
          false,
        ),
        endDate: deserializeParam(
          data['endDate'],
          ParamType.DateTime,
          false,
        ),
        startTime: deserializeParam(
          data['startTime'],
          ParamType.DateTime,
          false,
        ),
        endTime: deserializeParam(
          data['endTime'],
          ParamType.DateTime,
          false,
        ),
        allDay: deserializeParam(
          data['allDay'],
          ParamType.bool,
          false,
        ),
        durationMinutes: deserializeParam(
          data['durationMinutes'],
          ParamType.int,
          false,
        ),
        locationType: deserializeParam(
          data['locationType'],
          ParamType.String,
          false,
        ),
        locationName: deserializeParam(
          data['locationName'],
          ParamType.String,
          false,
        ),
        serviceProviderName: deserializeParam(
          data['serviceProviderName'],
          ParamType.String,
          false,
        ),
        completionStatus: deserializeParam(
          data['completionStatus'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'ActivityDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is ActivityDataStruct &&
        id == other.id &&
        activityType == other.activityType &&
        horseId == other.horseId &&
        title == other.title &&
        date == other.date &&
        time == other.time &&
        notes == other.notes &&
        isCompleted == other.isCompleted &&
        createdAt == other.createdAt &&
        updatedAt == other.updatedAt &&
        stableId == other.stableId &&
        customTitle == other.customTitle &&
        listEquality.equals(assigneeUserIds, other.assigneeUserIds) &&
        startDate == other.startDate &&
        endDate == other.endDate &&
        startTime == other.startTime &&
        endTime == other.endTime &&
        allDay == other.allDay &&
        durationMinutes == other.durationMinutes &&
        locationType == other.locationType &&
        locationName == other.locationName &&
        serviceProviderName == other.serviceProviderName &&
        completionStatus == other.completionStatus;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        activityType,
        horseId,
        title,
        date,
        time,
        notes,
        isCompleted,
        createdAt,
        updatedAt,
        stableId,
        customTitle,
        assigneeUserIds,
        startDate,
        endDate,
        startTime,
        endTime,
        allDay,
        durationMinutes,
        locationType,
        locationName,
        serviceProviderName,
        completionStatus
      ]);
}

ActivityDataStruct createActivityDataStruct({
  int? id,
  String? activityType,
  int? horseId,
  String? title,
  DateTime? date,
  DateTime? time,
  String? notes,
  bool? isCompleted,
  DateTime? createdAt,
  DateTime? updatedAt,
  String? stableId,
  String? customTitle,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? startTime,
  DateTime? endTime,
  bool? allDay,
  int? durationMinutes,
  String? locationType,
  String? locationName,
  String? serviceProviderName,
  String? completionStatus,
}) =>
    ActivityDataStruct(
      id: id,
      activityType: activityType,
      horseId: horseId,
      title: title,
      date: date,
      time: time,
      notes: notes,
      isCompleted: isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt,
      stableId: stableId,
      customTitle: customTitle,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      allDay: allDay,
      durationMinutes: durationMinutes,
      locationType: locationType,
      locationName: locationName,
      serviceProviderName: serviceProviderName,
      completionStatus: completionStatus,
    );
