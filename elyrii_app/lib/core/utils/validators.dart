/// Validators partagés de l'application.
abstract final class Validators {
  /// Expression rationnelle équivalente à la validation HTML5 (`input[type=email]`),
  /// alignée sur le comportement du package `email_validator` previously utilisé.
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
    r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  /// Retourne vrai si [value] est une adresse e-mail syntaxiquement valide.
  static bool isValidEmail(String value) =>
      value.isNotEmpty && _emailRegExp.hasMatch(value);
}
