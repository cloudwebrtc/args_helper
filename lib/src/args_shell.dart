part of args_helper.args_shell;

/**
 * Command descriptor.
 */
class ArgsCommand {
  /**
   * Arguments parser.
   */
  final ArgParser argParser;

  /**
   * Command description.
   */
  final String description;

  /**
   * Command name.
   */
  final String name;

  /**
   * Original command if this command are an alias.
   */
  final ArgsCommand original;

  /**
   * Required options.
   */
  final Set<String> requiredOptions;

  /**
   * Remaining arguments descriptor.
   */
  final ArgsRest rest;

  ArgsCommand({this.argParser, this.description, this.name, this.original, this.requiredOptions, this.rest});

  /**
    * Returns the string representation.
    */
  String toString() {
    return name;
  }
}

/**
 * Remaining arguments descriptor.
 */
class ArgsRest {
  /**
   * Indicates that multiple arguments allowed or not.
   */
  bool allowMultiple;

  /**
   * Help text on these remaining arguments.
   */
  final String help;

  /**
   * Name used for generating the string "usage".
   */
  String name;

  /**
   * Indicates that the remaining arguments are required or not.
   */
  final bool required;

  /**
   * Usage text on these remaining arguments.
   */
  final String usage;

  ArgsRest({this.allowMultiple, this.help, this.name, this.required, this.usage});

  /**
   * Returns the string representation.
   */
  String toString() {
    if (usage != null && !usage.isEmpty) {
      return usage;
    }

    var argument = "argument";
    if (name != null && !name.isEmpty) {
      argument = name;
    }

    var sb = new StringBuffer();
    if (!required) {
      sb.write("[");
    }

    sb.write(argument);
    if (allowMultiple) {
      sb.write(" ...");
    }

    if (!required) {
      sb.write("]");
    }

    return sb.toString();
  }
}

/**
 * Command shell descriptor.
 */
class ArgsShell {
  /**
   * Shell commands.
   */
  final Map<String, ArgsCommand> commands;

  /**
   * Shell description.
   */
  final String description;

  /**
   * Shell name.
   */
  final String name;

  ArgsShell({this.commands, this.description, this.name});
}
