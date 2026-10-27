/// Shared application validators.
abstract final class Validators {
  /// Regular expression equivalent to HTML5 `input[type=email]` validation,
  /// matching the previously used `email_validator` package.
  static final RegExp _emailRegExp = RegExp(
    r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
    r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$',
  );

  /// Whether [value] is a syntactically valid email address.
  static bool isValidEmail(String value) =>
      value.isNotEmpty && _emailRegExp.hasMatch(value);
}
