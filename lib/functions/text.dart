class TextFunctions {
  String capitalizeFirst(String string) {
    if (string.isEmpty) {
      return string;
    }
    return "${string[0].toUpperCase()}${string.substring(1)}";
  }

  String capitalizeWords(String string) {
    if (string.isEmpty) {
      return string;
    }
    String newString = string
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
    String newString1 = newString
        .split('(')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join('(');
    String newString2 = newString1
        .split('-')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join('-');
    return newString2;
  }
}

final tf = TextFunctions(); // Functions for text manipulation
