import 'package:utilx/locale.dart';

abstract class Translations {
  String anime();
  String manga();
  String searchAnAnimeOrManga();
  String mostPopularAnimes();
  String topOngoingAnimes();
  String mostPopularMangas();
  String topOngoingMangas();
  String winter();
  String spring();
  String summer();
  String fall();
  String nEps(final String episodes);
  String nChs(final String chapters);
  String episodes();
  String chapters();
  String nMins(final String minutes);
  String nHrsNMins(final String hours, final String minutes);
  String relations();
  String cancelled();
  String releasing();
  String notYetReleased();
  String finished();
  String hiatus();
  String nsfw();
  String characters();
  String settings();
  String appearance();
  String darkMode();
  String accentColor();
  String backgroundColor();
  String disableAnimations();
  String useSystemTheme();
  String overview();
  String extensions();
  String by(final String value);
  String authenticatedAs(final String name);
  String anilist();
  String loginUsing(final String name);
  String somethingWentWrong();
  String trackYourProgressUsingAnilist();
  String current();
  String planning();
  String completed();
  String dropped();
  String paused();
  String repeating();
  String totalAnime();
  String episodesWatched();
  String meanScore();
  String timeSpent();
  String totalManga();
  String chaptersRead();
  String volumesRead();

  Locale get locale;

  static const String unknownCharacter = '?';
}
