class TextFunctions {
  String capitalizeFirst(String string) {
    if (string.isEmpty) {
      return string;
    }
    return "${string[0].toUpperCase()}${string.substring(1)}";
  }
}

final tf = TextFunctions(); // Functions for text manipulation