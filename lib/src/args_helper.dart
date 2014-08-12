part of args_helper;

/**
 * Command line arguments helper.
 */
class ArgsHelper<TProgram> {
  static List<String> _arguments;

  static ArgsCommand _command;

  Map<String, List<String>> _aliases;

  Map<String, ArgsCommand> _commands;

  Map _configuration;

  String _description;

  String _name;

  /**
   * Returns the arguments.
   */
  static List<String> get arguments {
    return _arguments.toList();
  }

  /**
   * Returns the current command.
   */
  static ArgsCommand get command {
    return _command;
  }

  /**
   * Runs the command line program.
   */
  void run(List<String> arguments, Map configuration) {
    if (arguments == null) {
      throw new ArgumentError("arguments: $arguments");
    }

    if (configuration == null) {
      throw new ArgumentError("configuration: $configuration");
    }

    _reset();
    _arguments = arguments.toList();
    _configuration = new Map.from(configuration);
    _parseHeader();
    _parseCommands();
    _execute();
  }

  String _camelize(String string) {
    var charCodes = <int>[];
    var length = string.length;
    var capitalize = false;
    for (var i = 0; i < length; i++) {
      var c = string[i];
      if (c == "_") {
        capitalize = true;
      } else if (capitalize) {
        capitalize = false;
        charCodes.add(c.toUpperCase().codeUnitAt(0));
      } else {
        charCodes.add(c.codeUnitAt(0));
      }
    }

    return new String.fromCharCodes(charCodes);
  }

  void _checkMethod(String commandName, Map<String, Option> options, ArgsRest
      rest) {
    var method = _findMethodByCommandName(commandName);
    if (method == null) {
      var methodName = _getMethodNameForCommand(commandName);
      var className = MirrorSystem.getName(reflect(this
          ).type.typeArguments.first.simpleName);
      throw new ArgsHelperException(
          "Type '$className' must have a method '$methodName' for '$commandName' command."
          );
    }

    var methodName = MirrorSystem.getName(method.simpleName);
    var parameters = method.parameters.toList();
    if (rest != null) {
      if (parameters.isEmpty || parameters.first.isOptional ||
          parameters.first.isNamed) {
        throw new ArgsHelperException(
            "Method '$methodName' must contain positional parameter for the arguments.");
      }

      var parameter = parameters.removeAt(0);
      if (!parameter.type.isAssignableTo(reflectType(List))) {
        var simpleName = MirrorSystem.getName(parameter.simpleName);
        throw new ArgsHelperException(
            "Parameter '$simpleName' in '$methodName' must be assignable to the 'List' type."
            );
      }
    }

    for (var parameter in parameters) {
      if (!parameter.isNamed) {
        var simpleName = MirrorSystem.getName(parameter.simpleName);
        throw new ArgsHelperException(
            "Method '$methodName' must not contain positional parameter '$simpleName'.");
      }
    }

    var unbound = new Set<String>();
    unbound.addAll(parameters.map((e) => MirrorSystem.getName(e.simpleName)));
    for (var optionName in options.keys) {
      if (optionName == "help") {
        continue;
      }

      var found = false;
      var option = options[optionName];
      Type type;
      if (option.isFlag) {
        type = bool;
      } else {
        if (option.isMultiple) {
          type = List;
        } else {
          type = String;
        }
      }

      var simpleName = new Symbol(optionName);
      for (var parameter in parameters) {
        if (parameter.simpleName == simpleName) {
          unbound.remove(optionName);
          found = true;
          if (!parameter.type.isAssignableTo(reflectType(type))) {
            var parameterType = parameter.type.reflectedType;
            throw new ArgsHelperException(
                "Parameter '$parameterType $optionName' in method '$methodName' must be assignable to the '$type' type."
                );
          }
        }
      }

      if (!found) {
        throw new ArgsHelperException(
            "Parameter '$type $optionName' not found in method '$methodName'.");
      }
    }

    if (!unbound.isEmpty) {
      throw new ArgsHelperException(
          "Parameter '${unbound.first}' in '$methodName' has no associated option.");
    }
  }

  bool _configGetBool(Map config, String name, bool defaultValue, List<String>
      parents) {
    var value = config[name];
    if (value is bool) {
      return value;
    }

    if (value == null) {
      return defaultValue;
    }

    _errorSectionTypeMismatch(name, bool, parents);
    return null;
  }

  List _configGetList(Map config, String name, List defaultValue, List<String>
      parents) {
    var value = config[name];
    if (value is List) {
      return value;
    }

    if (value == null) {
      return defaultValue;
    }

    _errorSectionTypeMismatch(name, List, parents);
    return null;
  }

  Map _configGetMap(Map config, String name, Map defaultValue, List<String>
      parents) {
    var value = config[name];
    if (value is Map) {
      return value;
    }

    if (value == null) {
      return defaultValue;
    }

    _errorSectionTypeMismatch(name, Map, parents);
    return null;
  }

  String _configGetString(Map config, String name, String
      defaultValue, List<String> parents) {
    var value = config[name];
    if (value is String) {
      return value;
    }

    if (value == null) {
      return defaultValue;
    }

    _errorSectionTypeMismatch(name, String, parents);
    return null;
  }

  ArgsCommand _createCommandAlias(String commandName, ArgsCommand original) {
    var command = new ArgsCommand(argParser: original.argParser, description:
        original.description, name: commandName, original: original, rest: original.rest
        );
    return command;
  }

  void _errorSectionTypeMismatch(String name, Type type, List<String> parents) {
    var parts = parents.toList();
    parts.add(name);
    var section = _getSectionName(parts);
    throw new ArgsHelperException("Section '$section' must be of type '$type'."
        );
  }

  void _execute() {
    var commandName = "";
    var index = 0;
    var lastIndex = 0;
    for (var argument in _arguments) {
      index++;
      if (argument.startsWith("-")) {
        break;
      }

      if (commandName.isEmpty) {
        commandName = argument;
      } else {
        commandName = "$commandName $argument";
      }

      if (_commands.containsKey(commandName)) {
        _command = _commands[commandName];
        lastIndex = index;
      }
    }

    if (_command == null) {
      if (commandName.isEmpty) {
        _usage();
        return;
      } else {
        print("Command not found: '$commandName'.");
        print("");
        var subcommands = _findSubcommands(commandName);
        if (subcommands.isEmpty) {
          _usage();
          return;
        } else {
          _usageForSubcommands(commandName, subcommands);
          return;
        }
      }
    }

    var arguments = _arguments.sublist(lastIndex);
    commandName = _command.name;
    ArgResults argResults;
    try {
      argResults = _command.argParser.parse(arguments);
    } on FormatException catch (e) {
      print(e.message.replaceFirst("FormatException: ", ""));
      print("");
      _usageForCommand(_command, argResults);
      return;
    }

    MethodMirror method;
    if (_command.original == null) {
      method = _findMethodByCommandName(commandName);
    } else {
      method = _findMethodByCommandName(_command.original.name);
    }

    // This should not happen.
    if (method == null) {
      var methodName = _getMethodNameForCommand(commandName);
      print("Method not found: '$methodName'.");
      print("");
      _usage();
      return;
    }

    if (argResults.options.contains("help")) {
      if (argResults["help"]) {
        _usageForCommand(command, argResults);
        return;
      }
    }

    var commandRest = command.rest;
    var argRest = argResults.rest;
    if (commandRest != null) {
      // Remaining arguments (rest) required
      if (argRest.isEmpty && commandRest.required) {
        print("Command '$commandName' requires an arguments.");
        print("");
        _usageForCommand(command, argResults);
        return;
      }
    } else {
      // Remaining arguments (rest) not allowed
      if (!argRest.isEmpty) {
        print("Command '$commandName' does not take any arguments.");
        print("");
        _usageForCommand(command, argResults);
        return;
      }
    }

    _executeCommand(command, method, argResults);
  }

  void _executeCommand(ArgsCommand command, MethodMirror method, ArgResults
      argResults) {
    var program = reflectClass(TProgram).newInstance(new Symbol(""), []);
    var namedArguments = {};
    var positionalArguments = [];
    var parameters = method.parameters;
    if (command.rest != null) {
      positionalArguments.add(argResults.rest);
    }

    for (var optionName in argResults.options) {
      if (optionName != "help") {
        namedArguments[new Symbol(optionName)] = argResults[optionName];
      }
    }

    program.invoke(method.simpleName, positionalArguments, namedArguments);
  }

  MethodMirror _findMethodByCommandName(String commandName) {
    var methodName = _getMethodNameForCommand(commandName);
    var typeMirror = reflectClass(TProgram);
    var declaration = typeMirror.declarations[new Symbol(methodName)];
    if (declaration is MethodMirror) {
      return declaration;
    }

    return null;
  }

  List<String> _findSubcommands(String commandName) {
    var subcommands = <String>[];
    for (var key in _commands.keys) {
      if (key.startsWith(commandName)) {
        subcommands.add(key);
      }
    }

    return subcommands;
  }

  String _getMethodNameForCommand(String commandName) {
    commandName = commandName.replaceAll(" ", "_");
    commandName = _camelize(commandName);
    return commandName + "Command";
  }

  String _getScriptName() {
    if (_name != null && !_name.isEmpty) {
      return _name;
    }

    var script = Platform.script.toFilePath();
    var index = script.lastIndexOf(Platform.pathSeparator);
    if (index == -1) {
      return script;
    }

    return script.substring(index + 1);
  }

  String _getSectionName(List parts, [String separator = "."]) {
    return parts.join(separator);
  }

  String _normalizeCommandName(String commandName) {
    var parts = <String>[];
    for (var part in commandName.trim().split(" ")) {
      if (!part.isEmpty) {
        parts.add(part);
      }
    }

    return parts.join(" ");
  }

  ArgsCommand _parseCommand(String commandName, Map section, List parents) {
    var parent = <String>[];
    parent.addAll(parents);
    parent.add(commandName);
    var options = _configGetMap(section, "options", {}, parent);
    var description = _configGetString(section, "description", "", parent);
    var aliases = _configGetList(section, "aliases", [], parent);
    var restSection = _configGetMap(section, "rest", null, parent);
    ArgsRest rest;
    if (restSection != null) {
      var restParent = parent.toList();
      restParent.add("rest");
      var help = _configGetString(restSection, "help", null, restParent);
      var required = _configGetBool(restSection, "required", false, restParent);
      var usage = _configGetString(restSection, "usage", null, restParent);
      rest = new ArgsRest(help: help, required: required, usage: usage);
    }

    var parser = new ArgParser();
    var command = new ArgsCommand(argParser: parser, description: description,
        name: commandName, rest: rest);
    _commands[commandName] = command;

    if (options == null) {
      options = {};
    }

    _parseOptions(options, parser, ["commands", commandName, "options"]);
    if (!parser.options.containsKey("help")) {
      parser.addFlag("help", abbr: "h", help:
          "Print usage information for this command.", negatable: false);
    }

    _checkMethod(commandName, parser.options, rest);
    return command;
  }

  void _parseCommands() {
    Map commands = _configGetMap(_configuration, "commands", null, []);
    if (commands == null) {
      throw new ArgsHelperException("Section 'commands' not found.");
    }

    for (var key in commands.keys) {
      key = "$key";
      var parent = ["commands"];
      var commandName = _normalizeCommandName(key);
      if (commandName.isEmpty) {
        throw new ArgsHelperException("Command must have a name.");
      }

      var commandSection = _configGetMap(commands, key, {}, parent);
      var command = _parseCommand(commandName, commandSection, parent);
      _commands[commandName] = command;
      var aliasesParent = <String>[];
      aliasesParent.addAll(parent);
      aliasesParent.add(key);
      var aliases = _configGetList(commandSection, "aliases", [], aliasesParent
          );
      for (var alias in aliases) {
        alias = "$alias";
        var commandName = _normalizeCommandName(alias);
        _commands[commandName] = _createCommandAlias(commandName, command);
      }
    }
  }

  void _parseHeader() {
    _description = _configGetString(_configuration, "description", null, []);
    _name = _configGetString(_configuration, "name", null, []);
  }

  void _parseOptions(Map options, ArgParser parser, List parents) {
    for (var optionName in options.keys) {
      optionName = "$optionName";
      var parent = <String>[];
      parent.addAll(parents);
      parent.add(optionName);
      var option = _configGetMap(options, optionName, {}, parent);
      var abbr = _configGetString(option, "abbr", null, parent);
      var help = _configGetString(option, "help", null, parent);
      var hide = _configGetBool(option, "hide", false, parent);
      var isFlag = _configGetBool(option, "isFlag", false, parent);
      if (isFlag) {
        var defaultsTo = _configGetBool(option, "defaultsTo", false, parent);
        var negatable = _configGetBool(option, "negatable", true, parent);
        parser.addFlag(optionName, abbr: abbr, defaultsTo: defaultsTo, help:
            help, hide: hide, negatable: negatable);
      } else {
        var allowed = <String>[];
        for (var element in _configGetList(option, "allowed", [], parent)) {
          allowed.add(element.toString());
        }

        if (allowed.isEmpty) {
          allowed = null;
        }

        var allowedHelp = <String, String> {};
        Map allowedHelpSection = _configGetMap(option, "allowedHelp", {}, parent
            );
        for (var key in allowedHelpSection.keys) {
          allowedHelp[key.toString()] = allowedHelpSection[key].toString();
        }

        if (allowedHelp.isEmpty) {
          allowedHelp = null;
        }

        var allowMultiple = _configGetBool(option, "allowMultiple", false,
            parent);
        var defaultsTo = _configGetString(option, "defaultsTo", null, parent);
        var valueHelp = _configGetString(option, "valueHelp", null, parent);
        parser.addOption(optionName, abbr: abbr, allowed: allowed, allowedHelp:
            allowedHelp, allowMultiple: allowMultiple, defaultsTo: defaultsTo, help: help,
            hide: hide, valueHelp: valueHelp);
      }
    }
  }

  void _reset() {
    _arguments = <String>[];
    _aliases = <String, List<String>> {};
    _commands = <String, ArgsCommand> {};
    _command = null;
    _configuration = {};
    _description = null;
    _name = null;
  }

  void _usage() {
    var sb = new StringBuffer();
    if (_description != null && !_description.isEmpty) {
      sb.writeln(_description);
    }

    sb.write("Usage: ");
    sb.write(_getScriptName());
    sb.writeln(" command [options] [arguments]");

    if (!_commands.isEmpty) {
      sb.writeln("List of available commands:");
    }

    var commands = _commands.values.toList();
    commands.sort((a, b) => a.name.compareTo(b.name));
    int maxLength = commands.fold(0, (l, e) => e.name.length > l ? e.name.length
        : l);

    for (var command in commands) {
      var name = command.name;
      if (name.isEmpty) {
        continue;
      }

      var length = name.length;
      name = name.padRight(maxLength + 2, " ");
      var description = command.description;
      if (description == null || description.isEmpty) {
        description = "";
      }

      sb.write(" ");
      sb.write(name);
      sb.writeln(description);
    }

    print(sb);
  }

  void _usageForCommand(ArgsCommand command, ArgResults argResults) {
    var argParser = command.argParser;
    var sb = new StringBuffer();
    var description = command.description;
    if (description != null && !description.isEmpty) {
      sb.writeln(description);
    }

    sb.write("Usage: ");
    sb.write(_getScriptName());
    sb.write(" ");
    sb.write(command.name);
    if (!argParser.options.isEmpty) {
      sb.write(" ");
      sb.write("[options]");
    }

    if (command.rest != null) {
      sb.write(" ");
      sb.write(command.rest);
    }

    sb.writeln();
    if (!argParser.options.isEmpty) {
      var usage = argParser.getUsage();
      sb.writeln("List of available options:");
      sb.write(usage);
    }

    // TODO: Help about remaning arguments
    print(sb.toString());
  }

  void _usageForSubcommands(String commandName, List<String> subcommands) {
    var sb = new StringBuffer();
    if (_description != null && !_description.isEmpty) {
      sb.writeln(_description);
    }

    sb.write("Usage: ");
    sb.write(_getScriptName());
    sb.writeln(" command [options] [arguments]");
    sb.writeln("List of available subcommands:");
    var keys = subcommands.toList();
    keys.sort((a, b) => a.compareTo(b));
    int maxLength = keys.fold(0, (l, e) => e.length > l ? e.length : l);
    keys = keys.where((e) => e.startsWith(commandName)).toList();
    for (var key in keys) {
      var command = _commands[key];
      if (command == null) {
        continue;
      }

      var name = command.name;
      var length = name.length;
      name = name.padRight(maxLength + 2, " ");
      var description = command.description;
      if (description == null || description.isEmpty) {
        description = "";
      }

      sb.write(" ");
      sb.write(name);
      sb.writeln(description);
    }

    print(sb);
  }
}

class ArgsHelperException implements Exception {
  final String message;

  ArgsHelperException(this.message);

  String toString() {
    return "ArgsHelperException: $message";
  }
}

/**
 * Arguments command description.
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
  ArgsCommand original;

  /**
   * Remaining arguments descriptor.
   */
  final ArgsRest rest;

  ArgsCommand({this.argParser, this.description, this.name, this.original, this.rest});

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
   * Help text on these remaining arguments.
   */
  final String help;

  /**
   * Indicates that the remaining arguments are required.
   */
  final bool required;

  /**
   * Usage text on these remaining arguments.
   */
  final String usage;

  ArgsRest({this.help, this.required, this.usage});

  /**
   * Returns the string representation.
   */
  String toString() {
    var sb = new StringBuffer();
    if (!required) {
      sb.write("[");
    }

    if (usage == null || usage.isEmpty) {
      sb.write("arguments");
    } else {
      sb.write(usage);
    }

    if (!required) {
      sb.write("]");
    }

    return sb.toString();

  }
}
