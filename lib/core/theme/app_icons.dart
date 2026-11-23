import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Every icon in Looma, from one rounded set: Phosphor, regular weight.
/// Filled versions only where something is "on" (the active tab, a saved
/// post, a pinned card, a liked comment).
///
/// The Quick exit disguises (weather, calculator) keep the phone's stock
/// icons on purpose: they must look like ordinary apps.
class AppIcons {
  AppIcons._();

  // Tabs
  static const discuss = PhosphorIconsRegular.chatsCircle;
  static const discussActive = PhosphorIconsFill.chatsCircle;
  static const care = PhosphorIconsRegular.heart;
  static const careActive = PhosphorIconsFill.heart;
  static const me = PhosphorIconsRegular.userCircle;
  static const meActive = PhosphorIconsFill.userCircle;

  // Navigation
  static const chevronRight = PhosphorIconsRegular.caretRight;
  static const chevronLeft = PhosphorIconsRegular.caretLeft;
  static const back = PhosphorIconsRegular.caretLeft;
  static const arrowRight = PhosphorIconsRegular.arrowRight;
  static const arrowUp = PhosphorIconsRegular.arrowUp;
  static const close = PhosphorIconsRegular.x;
  static const check = PhosphorIconsRegular.check;
  static const add = PhosphorIconsRegular.plus;
  static const addCircle = PhosphorIconsRegular.plusCircle;
  static const removeCircle = PhosphorIconsRegular.minusCircle;
  static const more = PhosphorIconsRegular.dotsThreeCircle;

  // Posts
  static const write = PhosphorIconsRegular.pencilSimpleLine;
  static const reply = PhosphorIconsRegular.chatCircle;
  static const meToo = PhosphorIconsRegular.heart;
  static const meTooOn = PhosphorIconsFill.heart;
  static const bookmark = PhosphorIconsRegular.bookmarkSimple;
  static const bookmarkOn = PhosphorIconsFill.bookmarkSimple;
  static const pin = PhosphorIconsFill.pushPin;
  static const flag = PhosphorIconsRegular.flag;
  static const copy = PhosphorIconsRegular.copy;
  static const myPosts = PhosphorIconsRegular.fileText;
  static const delete = PhosphorIconsRegular.trash;
  static const journal = PhosphorIconsRegular.notePencil;

  // Care
  static const breathe = PhosphorIconsRegular.wind;
  static const ground = PhosphorIconsRegular.hand;
  static const mood = PhosphorIconsRegular.smiley;
  static const guides = PhosphorIconsRegular.bookOpen;
  static const book = PhosphorIconsRegular.book;
  static const directory = PhosphorIconsRegular.addressBook;
  static const askTeam = PhosphorIconsRegular.question;
  static const safety = PhosphorIconsRegular.shield;
  static const shieldCheck = PhosphorIconsRegular.shieldCheck;
  static const phone = PhosphorIconsRegular.phone;
  static const phoneCall = PhosphorIconsRegular.phoneCall;
  static const message = PhosphorIconsRegular.chatText;
  static const chat = PhosphorIconsRegular.chatCircle;
  static const globe = PhosphorIconsRegular.globe;
  static const support = PhosphorIconsRegular.headset;
  static const mobile = PhosphorIconsRegular.deviceMobile;
  static const person = PhosphorIconsRegular.user;
  static const personAdd = PhosphorIconsRegular.userPlus;
  static const people = PhosphorIconsRegular.usersThree;
  static const mapPin = PhosphorIconsRegular.mapPin;
  static const key = PhosphorIconsRegular.key;
  static const history = PhosphorIconsRegular.clockCounterClockwise;
  static const calendar = PhosphorIconsRegular.calendarBlank;

  // Me & privacy
  static const lock = PhosphorIconsRegular.lock;
  static const eye = PhosphorIconsRegular.eye;
  static const eyeSlash = PhosphorIconsRegular.eyeSlash;
  static const passcode = PhosphorIconsRegular.hash;
  static const faceId = PhosphorIconsRegular.userCircleCheck;
  static const fingerprint = PhosphorIconsRegular.fingerprint;
  static const backspace = PhosphorIconsRegular.backspace;
  static const envelope = PhosphorIconsRegular.envelope;
  static const blocked = PhosphorIconsRegular.prohibit;
  static const signOut = PhosphorIconsRegular.signOut;
  static const gentle = PhosphorIconsRegular.leaf;
  static const reduceMotion = PhosphorIconsRegular.spiral;
  static const weather = PhosphorIconsRegular.cloudSun;
  static const heart = PhosphorIconsRegular.heart;

  // Line-art avatars (picked from the alias)
  static const avatarFlower = PhosphorIconsRegular.flower;
  static const avatarLeaf = PhosphorIconsRegular.leaf;
  static const avatarMoon = PhosphorIconsRegular.moonStars;
  static const avatarSun = PhosphorIconsRegular.sun;
  static const avatarBird = PhosphorIconsRegular.bird;
  static const avatarButterfly = PhosphorIconsRegular.butterfly;
  static const avatarCat = PhosphorIconsRegular.cat;
  static const avatarFeather = PhosphorIconsRegular.feather;
  static const avatarTulip = PhosphorIconsRegular.flowerTulip;
  static const avatarLotus = PhosphorIconsRegular.flowerLotus;
  static const heartFilled = PhosphorIconsFill.heart;
}
