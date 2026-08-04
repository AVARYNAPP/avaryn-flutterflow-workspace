// ignore_for_file: unnecessary_getters_setters

import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Persistent local prototype model shared by the AVARYN horse list, detail
/// and edit flows.
class HorseProfileDataStruct extends BaseStruct {
  HorseProfileDataStruct({
    /// HorseProfileData.id
    int? id,

    /// HorseProfileData.officialName
    String? officialName,

    /// HorseProfileData.callName
    String? callName,

    /// HorseProfileData.photoData
    String? photoData,

    /// HorseProfileData.discipline
    String? discipline,

    /// HorseProfileData.competitionClass
    String? competitionClass,

    /// HorseProfileData.birthDate
    DateTime? birthDate,

    /// HorseProfileData.sex
    String? sex,

    /// HorseProfileData.breed
    String? breed,

    /// HorseProfileData.color
    String? color,

    /// HorseProfileData.passportNumber
    String? passportNumber,

    /// HorseProfileData.chipNumber
    String? chipNumber,

    /// HorseProfileData.owner
    String? owner,

    /// HorseProfileData.rider
    String? rider,

    /// HorseProfileData.stableLocation
    String? stableLocation,

    /// HorseProfileData.notes
    String? notes,

    /// HorseProfileData.dayForm
    String? dayForm,

    /// HorseProfileData.attention
    String? attention,

    /// HorseProfileData.nextActivity
    String? nextActivity,

    /// Optional date through which the horse passport remains valid.
    DateTime? passportExpiryDate,

    /// Optional stable identifier; older local horses safely fall back to the
    /// selected local stable.
    String? stableId,
  })  : _id = id,
        _officialName = officialName,
        _callName = callName,
        _photoData = photoData,
        _discipline = discipline,
        _competitionClass = competitionClass,
        _birthDate = birthDate,
        _sex = sex,
        _breed = breed,
        _color = color,
        _passportNumber = passportNumber,
        _chipNumber = chipNumber,
        _owner = owner,
        _rider = rider,
        _stableLocation = stableLocation,
        _notes = notes,
        _dayForm = dayForm,
        _attention = attention,
        _nextActivity = nextActivity,
        _passportExpiryDate = passportExpiryDate,
        _stableId = stableId;

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "officialName" field.
  String? _officialName;
  String get officialName => _officialName ?? '';
  set officialName(String? val) => _officialName = val;

  bool hasOfficialName() => _officialName != null;

  // "callName" field.
  String? _callName;
  String get callName => _callName ?? '';
  set callName(String? val) => _callName = val;

  bool hasCallName() => _callName != null;

  // "photoData" field.
  String? _photoData;
  String get photoData => _photoData ?? '';
  set photoData(String? val) => _photoData = val;

  bool hasPhotoData() => _photoData != null;

  // "discipline" field.
  String? _discipline;
  String get discipline => _discipline ?? '';
  set discipline(String? val) => _discipline = val;

  bool hasDiscipline() => _discipline != null;

  // "competitionClass" field.
  String? _competitionClass;
  String get competitionClass => _competitionClass ?? '';
  set competitionClass(String? val) => _competitionClass = val;

  bool hasCompetitionClass() => _competitionClass != null;

  // "birthDate" field.
  DateTime? _birthDate;
  DateTime? get birthDate => _birthDate;
  set birthDate(DateTime? val) => _birthDate = val;

  bool hasBirthDate() => _birthDate != null;

  // "sex" field.
  String? _sex;
  String get sex => _sex ?? '';
  set sex(String? val) => _sex = val;

  bool hasSex() => _sex != null;

  // "breed" field.
  String? _breed;
  String get breed => _breed ?? '';
  set breed(String? val) => _breed = val;

  bool hasBreed() => _breed != null;

  // "color" field.
  String? _color;
  String get color => _color ?? '';
  set color(String? val) => _color = val;

  bool hasColor() => _color != null;

  // "passportNumber" field.
  String? _passportNumber;
  String get passportNumber => _passportNumber ?? '';
  set passportNumber(String? val) => _passportNumber = val;

  bool hasPassportNumber() => _passportNumber != null;

  // "chipNumber" field.
  String? _chipNumber;
  String get chipNumber => _chipNumber ?? '';
  set chipNumber(String? val) => _chipNumber = val;

  bool hasChipNumber() => _chipNumber != null;

  // "owner" field.
  String? _owner;
  String get owner => _owner ?? '';
  set owner(String? val) => _owner = val;

  bool hasOwner() => _owner != null;

  // "rider" field.
  String? _rider;
  String get rider => _rider ?? '';
  set rider(String? val) => _rider = val;

  bool hasRider() => _rider != null;

  // "stableLocation" field.
  String? _stableLocation;
  String get stableLocation => _stableLocation ?? '';
  set stableLocation(String? val) => _stableLocation = val;

  bool hasStableLocation() => _stableLocation != null;

  // "notes" field.
  String? _notes;
  String get notes => _notes ?? '';
  set notes(String? val) => _notes = val;

  bool hasNotes() => _notes != null;

  // "dayForm" field.
  String? _dayForm;
  String get dayForm => _dayForm ?? '';
  set dayForm(String? val) => _dayForm = val;

  bool hasDayForm() => _dayForm != null;

  // "attention" field.
  String? _attention;
  String get attention => _attention ?? '';
  set attention(String? val) => _attention = val;

  bool hasAttention() => _attention != null;

  // "nextActivity" field.
  String? _nextActivity;
  String get nextActivity => _nextActivity ?? '';
  set nextActivity(String? val) => _nextActivity = val;

  bool hasNextActivity() => _nextActivity != null;

  // "passportExpiryDate" field.
  DateTime? _passportExpiryDate;
  DateTime? get passportExpiryDate => _passportExpiryDate;
  set passportExpiryDate(DateTime? val) => _passportExpiryDate = val;

  bool hasPassportExpiryDate() => _passportExpiryDate != null;

  // "stableId" field.
  String? _stableId;
  String get stableId => _stableId ?? '';
  set stableId(String? val) => _stableId = val;

  bool hasStableId() => _stableId != null;

  static HorseProfileDataStruct fromMap(Map<String, dynamic> data) =>
      HorseProfileDataStruct(
        id: castToType<int>(data['id']),
        officialName: data['officialName'] as String?,
        callName: data['callName'] as String?,
        photoData: data['photoData'] as String?,
        discipline: data['discipline'] as String?,
        competitionClass: data['competitionClass'] as String?,
        birthDate: data['birthDate'] as DateTime?,
        sex: data['sex'] as String?,
        breed: data['breed'] as String?,
        color: data['color'] as String?,
        passportNumber: data['passportNumber'] as String?,
        chipNumber: data['chipNumber'] as String?,
        owner: data['owner'] as String?,
        rider: data['rider'] as String?,
        stableLocation: data['stableLocation'] as String?,
        notes: data['notes'] as String?,
        dayForm: data['dayForm'] as String?,
        attention: data['attention'] as String?,
        nextActivity: data['nextActivity'] as String?,
        passportExpiryDate: data['passportExpiryDate'] as DateTime?,
        stableId: data['stableId'] as String?,
      );

  static HorseProfileDataStruct? maybeFromMap(dynamic data) => data is Map
      ? HorseProfileDataStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'officialName': _officialName,
        'callName': _callName,
        'photoData': _photoData,
        'discipline': _discipline,
        'competitionClass': _competitionClass,
        'birthDate': _birthDate,
        'sex': _sex,
        'breed': _breed,
        'color': _color,
        'passportNumber': _passportNumber,
        'chipNumber': _chipNumber,
        'owner': _owner,
        'rider': _rider,
        'stableLocation': _stableLocation,
        'notes': _notes,
        'dayForm': _dayForm,
        'attention': _attention,
        'nextActivity': _nextActivity,
        'passportExpiryDate': _passportExpiryDate,
        'stableId': _stableId,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'officialName': serializeParam(
          _officialName,
          ParamType.String,
        ),
        'callName': serializeParam(
          _callName,
          ParamType.String,
        ),
        'photoData': serializeParam(
          _photoData,
          ParamType.String,
        ),
        'discipline': serializeParam(
          _discipline,
          ParamType.String,
        ),
        'competitionClass': serializeParam(
          _competitionClass,
          ParamType.String,
        ),
        'birthDate': serializeParam(
          _birthDate,
          ParamType.DateTime,
        ),
        'sex': serializeParam(
          _sex,
          ParamType.String,
        ),
        'breed': serializeParam(
          _breed,
          ParamType.String,
        ),
        'color': serializeParam(
          _color,
          ParamType.String,
        ),
        'passportNumber': serializeParam(
          _passportNumber,
          ParamType.String,
        ),
        'chipNumber': serializeParam(
          _chipNumber,
          ParamType.String,
        ),
        'owner': serializeParam(
          _owner,
          ParamType.String,
        ),
        'rider': serializeParam(
          _rider,
          ParamType.String,
        ),
        'stableLocation': serializeParam(
          _stableLocation,
          ParamType.String,
        ),
        'notes': serializeParam(
          _notes,
          ParamType.String,
        ),
        'dayForm': serializeParam(
          _dayForm,
          ParamType.String,
        ),
        'attention': serializeParam(
          _attention,
          ParamType.String,
        ),
        'nextActivity': serializeParam(
          _nextActivity,
          ParamType.String,
        ),
        'passportExpiryDate': serializeParam(
          _passportExpiryDate,
          ParamType.DateTime,
        ),
        'stableId': serializeParam(
          _stableId,
          ParamType.String,
        ),
      }.withoutNulls;

  static HorseProfileDataStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      HorseProfileDataStruct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        officialName: deserializeParam(
          data['officialName'],
          ParamType.String,
          false,
        ),
        callName: deserializeParam(
          data['callName'],
          ParamType.String,
          false,
        ),
        photoData: deserializeParam(
          data['photoData'],
          ParamType.String,
          false,
        ),
        discipline: deserializeParam(
          data['discipline'],
          ParamType.String,
          false,
        ),
        competitionClass: deserializeParam(
          data['competitionClass'],
          ParamType.String,
          false,
        ),
        birthDate: deserializeParam(
          data['birthDate'],
          ParamType.DateTime,
          false,
        ),
        sex: deserializeParam(
          data['sex'],
          ParamType.String,
          false,
        ),
        breed: deserializeParam(
          data['breed'],
          ParamType.String,
          false,
        ),
        color: deserializeParam(
          data['color'],
          ParamType.String,
          false,
        ),
        passportNumber: deserializeParam(
          data['passportNumber'],
          ParamType.String,
          false,
        ),
        chipNumber: deserializeParam(
          data['chipNumber'],
          ParamType.String,
          false,
        ),
        owner: deserializeParam(
          data['owner'],
          ParamType.String,
          false,
        ),
        rider: deserializeParam(
          data['rider'],
          ParamType.String,
          false,
        ),
        stableLocation: deserializeParam(
          data['stableLocation'],
          ParamType.String,
          false,
        ),
        notes: deserializeParam(
          data['notes'],
          ParamType.String,
          false,
        ),
        dayForm: deserializeParam(
          data['dayForm'],
          ParamType.String,
          false,
        ),
        attention: deserializeParam(
          data['attention'],
          ParamType.String,
          false,
        ),
        nextActivity: deserializeParam(
          data['nextActivity'],
          ParamType.String,
          false,
        ),
        passportExpiryDate: deserializeParam(
          data['passportExpiryDate'],
          ParamType.DateTime,
          false,
        ),
        stableId: deserializeParam(
          data['stableId'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'HorseProfileDataStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is HorseProfileDataStruct &&
        id == other.id &&
        officialName == other.officialName &&
        callName == other.callName &&
        photoData == other.photoData &&
        discipline == other.discipline &&
        competitionClass == other.competitionClass &&
        birthDate == other.birthDate &&
        sex == other.sex &&
        breed == other.breed &&
        color == other.color &&
        passportNumber == other.passportNumber &&
        chipNumber == other.chipNumber &&
        owner == other.owner &&
        rider == other.rider &&
        stableLocation == other.stableLocation &&
        notes == other.notes &&
        dayForm == other.dayForm &&
        attention == other.attention &&
        nextActivity == other.nextActivity &&
        passportExpiryDate == other.passportExpiryDate &&
        stableId == other.stableId;
  }

  @override
  int get hashCode => const ListEquality().hash([
        id,
        officialName,
        callName,
        photoData,
        discipline,
        competitionClass,
        birthDate,
        sex,
        breed,
        color,
        passportNumber,
        chipNumber,
        owner,
        rider,
        stableLocation,
        notes,
        dayForm,
        attention,
        nextActivity,
        passportExpiryDate,
        stableId
      ]);
}

HorseProfileDataStruct createHorseProfileDataStruct({
  int? id,
  String? officialName,
  String? callName,
  String? photoData,
  String? discipline,
  String? competitionClass,
  DateTime? birthDate,
  String? sex,
  String? breed,
  String? color,
  String? passportNumber,
  String? chipNumber,
  String? owner,
  String? rider,
  String? stableLocation,
  String? notes,
  String? dayForm,
  String? attention,
  String? nextActivity,
  DateTime? passportExpiryDate,
  String? stableId,
}) =>
    HorseProfileDataStruct(
      id: id,
      officialName: officialName,
      callName: callName,
      photoData: photoData,
      discipline: discipline,
      competitionClass: competitionClass,
      birthDate: birthDate,
      sex: sex,
      breed: breed,
      color: color,
      passportNumber: passportNumber,
      chipNumber: chipNumber,
      owner: owner,
      rider: rider,
      stableLocation: stableLocation,
      notes: notes,
      dayForm: dayForm,
      attention: attention,
      nextActivity: nextActivity,
      passportExpiryDate: passportExpiryDate,
      stableId: stableId,
    );
