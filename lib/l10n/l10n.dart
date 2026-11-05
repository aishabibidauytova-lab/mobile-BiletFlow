import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Supported UI languages. The order matches the lists in [_strings]:
/// [ru, en, kk].
enum AppLang {
  ru('ru', 'Русский'),
  en('en', 'English'),
  kk('kk', 'Қазақша');

  final String code;
  final String nativeName;
  const AppLang(this.code, this.nativeName);
}

/// Global language state. The root widget listens to it and rebuilds the app.
final l10n = L10n();

class L10n extends ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _key = 'bf_lang';

  AppLang _lang = AppLang.ru;
  AppLang get lang => _lang;

  /// Restores the saved language, else picks the device language (ru default).
  Future<void> load() async {
    String? saved;
    try {
      saved = await _storage.read(key: _key);
    } catch (_) {}
    final code = saved ?? PlatformDispatcher.instance.locale.languageCode;
    _lang = AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.ru);
  }

  Future<void> set(AppLang lang) async {
    if (lang == _lang) return;
    _lang = lang;
    notifyListeners();
    try {
      await _storage.write(key: _key, value: lang.code);
    } catch (_) {}
  }
}

/// Translates [key] into the current language. `{name}` placeholders are
/// replaced from [args]. Unknown keys are returned as-is.
String tr(String key, [Map<String, Object?> args = const {}]) {
  var s = _strings[key]?[l10n.lang.index] ?? key;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}

// Each entry: [Русский, English, Қазақша].
const _strings = <String, List<String>>{
  // --- Common ---
  'retry': ['Повторить', 'Retry', 'Қайталау'],
  'err.load': ['Не удалось загрузить данные', 'Could not load data', 'Деректерді жүктеу мүмкін болмады'],
  'free': ['Бесплатно', 'Free', 'Тегін'],
  'no': ['Нет', 'No', 'Жоқ'],
  'language': ['Язык', 'Language', 'Тіл'],

  // --- Dates ---
  'wd1': ['Пн', 'Mon', 'Дс'],
  'wd2': ['Вт', 'Tue', 'Сс'],
  'wd3': ['Ср', 'Wed', 'Ср'],
  'wd4': ['Чт', 'Thu', 'Бс'],
  'wd5': ['Пт', 'Fri', 'Жм'],
  'wd6': ['Сб', 'Sat', 'Сб'],
  'wd7': ['Вс', 'Sun', 'Жс'],
  'm1': ['ЯНВ', 'JAN', 'ҚАҢ'],
  'm2': ['ФЕВ', 'FEB', 'АҚП'],
  'm3': ['МАР', 'MAR', 'НАУ'],
  'm4': ['АПР', 'APR', 'СӘУ'],
  'm5': ['МАЙ', 'MAY', 'МАМ'],
  'm6': ['ИЮН', 'JUN', 'МАУ'],
  'm7': ['ИЮЛ', 'JUL', 'ШІЛ'],
  'm8': ['АВГ', 'AUG', 'ТАМ'],
  'm9': ['СЕН', 'SEP', 'ҚЫР'],
  'm10': ['ОКТ', 'OCT', 'ҚАЗ'],
  'm11': ['НОЯ', 'NOV', 'ҚАР'],
  'm12': ['ДЕК', 'DEC', 'ЖЕЛ'],

  // --- Categories ---
  'cat.Education': ['Образование', 'Education', 'Білім'],
  'cat.Music': ['Музыка', 'Music', 'Музыка'],
  'cat.Festival': ['Фестивали', 'Festivals', 'Фестивальдер'],
  'cat.Sport': ['Спорт', 'Sports', 'Спорт'],
  'cat.Theatre': ['Театр', 'Theatre', 'Театр'],
  'cat.Концерт': ['Концерт', 'Concert', 'Концерт'],

  // --- Home / navigation ---
  'nav.events': ['Афиша', 'Events', 'Афиша'],
  'nav.tickets': ['Билеты', 'Tickets', 'Билеттер'],
  'nav.orders': ['Заказы', 'Orders', 'Тапсырыстар'],
  'nav.checkin': ['Проверка', 'Check-in', 'Тексеру'],
  'title.tickets': ['Мои билеты', 'My tickets', 'Менің билеттерім'],
  'title.checkin': ['Проверка билетов', 'Ticket check-in', 'Билеттерді тексеру'],
  'menu.logout': ['Выйти', 'Log out', 'Шығу'],

  // --- Login ---
  'login.title': ['Вход в BiletFlow', 'Sign in to BiletFlow', 'BiletFlow-ға кіру'],
  'login.createTitle': ['Создание аккаунта', 'Create an account', 'Аккаунт құру'],
  'login.password': ['Пароль', 'Password', 'Құпия сөз'],
  'login.emailInvalid': ['Введите корректный email', 'Enter a valid email', 'Дұрыс email енгізіңіз'],
  'login.passwordEmpty': ['Введите пароль', 'Enter your password', 'Құпия сөзді енгізіңіз'],
  'login.requestFailed': [
    'Не удалось выполнить запрос. Попробуйте ещё раз.',
    'The request failed. Please try again.',
    'Сұранысты орындау мүмкін болмады. Қайталап көріңіз.'
  ],
  'login.signIn': ['Войти', 'Sign in', 'Кіру'],
  'login.register': ['Зарегистрироваться', 'Sign up', 'Тіркелу'],
  'login.haveAccount': ['Уже есть аккаунт? Войти', 'Already have an account? Sign in', 'Аккаунт бар ма? Кіру'],
  'login.noAccount': ['Нет аккаунта? Зарегистрироваться', 'No account? Sign up', 'Аккаунт жоқ па? Тіркелу'],

  // --- Events catalog ---
  'events.search': ['Поиск событий…', 'Search events…', 'Іс-шараларды іздеу…'],
  'events.all': ['Все', 'All', 'Барлығы'],
  'events.allEvents': ['Все события', 'All events', 'Барлық іс-шаралар'],
  'events.today': ['Сегодня', 'Today', 'Бүгін'],
  'events.pickDate': ['Выбрать дату', 'Pick a date', 'Күнді таңдау'],
  'events.none': [
    'Ничего не найдено. Попробуйте изменить фильтры.',
    'Nothing found. Try changing the filters.',
    'Ештеңе табылмады. Сүзгілерді өзгертіп көріңіз.'
  ],
  'events.reset': ['Сбросить фильтры', 'Reset filters', 'Сүзгілерді тастау'],
  'events.nearest': ['БЛИЖАЙШЕЕ', 'UP NEXT', 'ЕҢ ЖАҚЫН'],
  'events.from': ['от {price}', 'from {price}', '{price}-дан бастап'],
  'events.noTickets': ['Нет билетов', 'No tickets', 'Билет жоқ'],

  // --- Event page ---
  'detail.about': ['О событии', 'About', 'Іс-шара туралы'],
  'detail.tickets': ['Билеты', 'Tickets', 'Билеттер'],
  'detail.cancelled': ['Мероприятие отменено.', 'This event has been cancelled.', 'Іс-шара тоқтатылды.'],
  'detail.closed': ['Регистрация закрыта.', 'Registration is closed.', 'Тіркеу жабық.'],
  'detail.ticketsFailed': ['Не удалось загрузить билеты', 'Could not load tickets', 'Билеттерді жүктеу мүмкін болмады'],
  'detail.noSale': ['Билеты пока не продаются.', 'Tickets are not on sale yet.', 'Билеттер әзірге сатылмайды.'],
  'detail.ticketCount': ['Билетов: {n}', 'Tickets: {n}', 'Билеттер: {n}'],
  'detail.register': ['Зарегистрироваться', 'Register', 'Тіркелу'],
  'detail.order': ['Оформить заказ', 'Place order', 'Тапсырыс беру'],
  'ticketType.soldOut': ['Распродано', 'Sold out', 'Сатылып біткен'],
  'ticketType.closed': ['Продажи закрыты', 'Sales closed', 'Сату жабық'],
  'ticketType.left': ['Осталось: {n}', 'Left: {n}', 'Қалды: {n}'],
  'ticketType.less': ['Меньше', 'Fewer', 'Азырақ'],
  'ticketType.more': ['Больше', 'More', 'Көбірек'],

  // --- My tickets / ticket page ---
  'tickets.empty': [
    'У вас пока нет билетов.\nВыберите мероприятие в «Афише».',
    'You have no tickets yet.\nPick an event in "Events".',
    'Сізде әзірге билет жоқ.\n«Афишадан» іс-шара таңдаңыз.'
  ],
  'ticket.title': ['Билет', 'Ticket', 'Билет'],
  'ticket.valid': ['Действителен', 'Valid', 'Жарамды'],
  'ticket.used': ['Использован', 'Used', 'Пайдаланылған'],
  'ticket.cancelled': ['Отменён', 'Cancelled', 'Бас тартылды'],
  'ticket.qrFailed': [
    'Не удалось загрузить QR-код.\nПроверьте интернет.',
    'Could not load the QR code.\nCheck your connection.',
    'QR-кодты жүктеу мүмкін болмады.\nИнтернетті тексеріңіз.'
  ],
  'ticket.copy': ['Скопировать код', 'Copy code', 'Кодты көшіру'],
  'ticket.copied': ['Код скопирован', 'Code copied', 'Код көшірілді'],
  'ticket.hintValid': [
    'Покажите этот QR-код на входе. Не передавайте его другим: пройти по билету можно только один раз.',
    'Show this QR code at the entrance. Do not share it: a ticket works only once.',
    'Бұл QR-кодты кіреберісте көрсетіңіз. Басқаларға бермеңіз: билет бойынша тек бір рет өтуге болады.'
  ],
  'ticket.hintUsedAt': [
    'Вход по билету выполнен {date}.',
    'Entry with this ticket was recorded on {date}.',
    'Билет бойынша кіру {date} орындалды.'
  ],
  'ticket.hintUsed': [
    'Вход по билету уже выполнен.',
    'Entry with this ticket has already been recorded.',
    'Билет бойынша кіру орындалған.'
  ],
  'ticket.hintCancelled': [
    'Билет отменён и не действует.',
    'This ticket has been cancelled and is not valid.',
    'Билеттен бас тартылған, ол жарамсыз.'
  ],

  // --- Orders ---
  'orders.empty': ['Заказов пока нет.', 'No orders yet.', 'Тапсырыстар әзірге жоқ.'],
  'orders.number': ['Заказ №{id}', 'Order #{id}', 'Тапсырыс №{id}'],
  'orders.ticketsN': ['билетов: {n}', 'tickets: {n}', 'билет: {n}'],
  'order.pending': ['Ожидает оплаты', 'Awaiting payment', 'Төлем күтілуде'],
  'order.paid': ['Оплачен', 'Paid', 'Төленді'],
  'order.cancelled': ['Отменён', 'Cancelled', 'Бас тартылды'],
  'order.expired': ['Истёк', 'Expired', 'Мерзімі өтті'],
  'order.cancelTitle': ['Отменить заказ?', 'Cancel this order?', 'Тапсырыстан бас тарту керек пе?'],
  'order.cancelBody': [
    'Билеты из этого заказа станут недействительными.',
    'Tickets from this order will become invalid.',
    'Бұл тапсырыстағы билеттер жарамсыз болады.'
  ],
  'order.cancel': ['Отменить заказ', 'Cancel order', 'Тапсырыстан бас тарту'],
  'order.cancelled.toast': ['Заказ отменён', 'Order cancelled', 'Тапсырыстан бас тартылды'],
  'order.reservedUntil': [
    'Билеты забронированы до {date}',
    'Tickets are reserved until {date}',
    'Билеттер {date} дейін брондалған'
  ],
  'order.items': ['Состав заказа', 'Order summary', 'Тапсырыс құрамы'],
  'order.total': ['Итого', 'Total', 'Жиыны'],
  'order.demo': [
    'ДЕМО-ОПЛАТА: это симуляция для учебного проекта. Реальные деньги не списываются.',
    'DEMO PAYMENT: this is a simulation for a study project. No real money is charged.',
    'ДЕМО-ТӨЛЕМ: бұл оқу жобасына арналған имитация. Нақты ақша есептен шығарылмайды.'
  ],
  'order.confirmedToast': ['Регистрация подтверждена', 'Registration confirmed', 'Тіркеу расталды'],
  'order.paidToast': ['Оплата прошла (демо)', 'Payment succeeded (demo)', 'Төлем өтті (демо)'],
  'order.confirm': ['Подтвердить регистрацию', 'Confirm registration', 'Тіркеуді растау'],
  'order.pay': ['Оплатить (демо)', 'Pay (demo)', 'Төлеу (демо)'],
  'order.yourTickets': ['Ваши билеты', 'Your tickets', 'Сіздің билеттеріңіз'],

  // --- Check-in: events, scanner, search ---
  'checkin.noEvents': [
    'Вам пока не назначено ни одного мероприятия.\nОбратитесь к организатору.',
    'You are not assigned to any events yet.\nContact the organizer.',
    'Сізге әзірге ешқандай іс-шара тағайындалмаған.\nҰйымдастырушыға жүгініңіз.'
  ],
  'scan.promoQr': ['Это рекламный QR-код, а не билет.', 'This is a promo QR code, not a ticket.', 'Бұл жарнамалық QR-код, билет емес.'],
  'scan.failed': ['Ошибка проверки. Попробуйте ещё раз.', 'Check failed. Please try again.', 'Тексеру қатесі. Қайталап көріңіз.'],
  'scan.undone': ['Чек-ин отменён', 'Check-in undone', 'Чек-ин жойылды'],
  'scan.search': ['Поиск участника', 'Find attendee', 'Қатысушыны іздеу'],
  'scan.noCamera': [
    'Нет доступа к камере.\nРазрешите доступ в настройках телефона или воспользуйтесь поиском участника.',
    'No camera access.\nAllow it in your phone settings or use attendee search.',
    'Камераға қолжетімділік жоқ.\nТелефон баптауларында рұқсат беріңіз немесе қатысушыны іздеуді пайдаланыңыз.'
  ],
  'scan.hint': ['Наведите камеру на QR-код билета', 'Point the camera at the ticket QR code', 'Камераны билеттің QR-кодына бағыттаңыз'],
  'scan.torch': ['Фонарик', 'Torch', 'Шам'],
  'scan.switchCamera': ['Сменить камеру', 'Switch camera', 'Камераны ауыстыру'],
  'scan.out.success': ['БИЛЕТ ДЕЙСТВИТЕЛЕН', 'TICKET VALID', 'БИЛЕТ ЖАРАМДЫ'],
  'scan.out.used': ['УЖЕ ИСПОЛЬЗОВАН', 'ALREADY USED', 'БҰРЫН ПАЙДАЛАНЫЛҒАН'],
  'scan.out.cancelled': ['БИЛЕТ ОТМЕНЁН', 'TICKET CANCELLED', 'БИЛЕТТЕН БАС ТАРТЫЛҒАН'],
  'scan.out.wrongEvent': ['БИЛЕТ НА ДРУГОЕ СОБЫТИЕ', 'TICKET FOR ANOTHER EVENT', 'БАСҚА ІС-ШАРАҒА БИЛЕТ'],
  'scan.out.notTicket': ['ЭТО НЕ БИЛЕТ', 'NOT A TICKET', 'БҰЛ БИЛЕТ ЕМЕС'],
  'scan.out.invalid': ['НЕДЕЙСТВИТЕЛЬНЫЙ БИЛЕТ', 'INVALID TICKET', 'ЖАРАМСЫЗ БИЛЕТ'],
  'scan.out.error': ['ОШИБКА ПРОВЕРКИ', 'CHECK ERROR', 'ТЕКСЕРУ ҚАТЕСІ'],
  'scan.checkedInAt': ['Чек-ин: {time}', 'Checked in: {time}', 'Чек-ин: {time}'],
  'scan.undo': ['Отменить чек-ин', 'Undo check-in', 'Чек-инді болдырмау'],
  'att.checkedIn': ['Чек-ин выполнен: {email}', 'Checked in: {email}', 'Чек-ин орындалды: {email}'],
  'att.alreadyUsed': ['Билет уже использован', 'Ticket already used', 'Билет бұрын пайдаланылған'],
  'att.cancelled': ['Билет отменён', 'Ticket cancelled', 'Билеттен бас тартылған'],
  'att.failed': ['Не удалось выполнить чек-ин', 'Check-in failed', 'Чек-инді орындау мүмкін болмады'],
  'att.undoTitle': ['Отменить чек-ин?', 'Undo check-in?', 'Чек-инді жою керек пе?'],
  'att.undoBody': [
    '{email} ({code}) снова станет «не прибыл».',
    '{email} ({code}) will be marked as "not arrived" again.',
    '{email} ({code}) қайтадан «келмеген» болады.'
  ],
  'att.notArrived': ['Не прибыл', 'Not arrived', 'Келмеген'],
  'att.arrived': ['Прибыл', 'Arrived', 'Келді'],
  'att.hint': ['Email или код билета', 'Email or ticket code', 'Email немесе билет коды'],
  'att.none': ['Ничего не найдено', 'Nothing found', 'Ештеңе табылмады'],
  'att.checkIn': ['Чек-ин', 'Check in', 'Чек-ин'],

  // --- Server / network errors ---
  'api.sessionExpired': ['Сессия истекла. Войдите снова.', 'Session expired. Please sign in again.', 'Сессия аяқталды. Қайта кіріңіз.'],
  'api.forbidden': ['Нет доступа.', 'Access denied.', 'Қолжетімділік жоқ.'],
  'api.server': ['Ошибка сервера ({code})', 'Server error ({code})', 'Сервер қатесі ({code})'],
  'api.timeout': ['Нет ответа от сервера. Проверьте интернет.', 'The server is not responding. Check your connection.', 'Серверден жауап жоқ. Интернетті тексеріңіз.'],
  'api.noConnection': ['Нет соединения с сервером.', 'Cannot reach the server.', 'Сервермен байланыс жоқ.'],
};
