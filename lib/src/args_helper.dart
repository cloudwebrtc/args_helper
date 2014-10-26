part of args_helper;

/**
 * Command line arguments helper.
 */
class ArgsHelper<TProgram> {
  static List<String> _arguments;

  static ArgsCommand _command;

  bool _hasErrors;

  Logger _logger;

  ArgsShell _shell;

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
    _parse(new Map.from(configuration));
    _checkMethods();
    _checkFoundErrors();
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

  void _checkMethods() {
    for (var command in _shell.commands.values) {
      if (command.original == null) {
        _checkMethod(command.name, command.argParser.options, command.rest);
      }
    }
  }

  void _checkFoundErrors() {
    if (_hasErrors) {
      throw new ArgsHelperException("Found an errors in the configuration of '$TProgram'.");
    }
  }

  void _checkMethod(String commandName, Map<String, Option> options, ArgsRest rest) {
    var method = _findMethodByCommandName(commandName);
    if (method == null) {
      var methodName = _getMethodNameForCommand(commandName);
      var className = MirrorSystem.getName(reflect(this).type.typeArguments.first.simpleName);
      var message = "Type '$className' must have a method '$methodName' for '$commandName' command.";
      _logError(message);
      return;
    }

    var methodName = MirrorSystem.getName(method.simpleName);
    var parameters = method.parameters.toList();
    if (rest != null) {
      var foundRestParameter = !parameters.isEmpty && !(parameters.first.isOptional || parameters.first.isNamed);
      if (foundRestParameter) {
        var parameter = parameters.removeAt(0);
        Type type;
        if (rest.allowMultiple) {
          type = List;
        } else {
          type = String;
        }

        if (!parameter.type.isAssignableTo(reflectType(type))) {
          var simpleName = MirrorSystem.getName(parameter.simpleName);
          var message = "Parameter '$simpleName' in '$methodName' must be assignable to the '$type' type.";
          _logError(message);
        }
      } else {
        var message = "Method '$methodName' must contain positional parameter for the arguments.";
        _logError(message);
      }
    }

    for (var parameter in parameters) {
      if (!parameter.isNamed) {
        var simpleName = MirrorSystem.getName(parameter.simpleName);
        var message = "Method '$methodName' must not contain positional parameter '$simpleName'.";
        _logError(message);
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
            var message = "Parameter '$parameterType $optionName' in method '$methodName' must be assignable to the '$type' type.";
            _logError(message);
          }
        }
      }

      if (!found) {
        var message = "Parameter '$type $optionName' not found in method '$methodName'.";
        _logError(message);

      }
    }

    if (!unbound.isEmpty) {
      var message = "Parameter '${unbound.first}' in '$methodName' has no associated option.";
      _logError(message);
    }
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

      if (_shell.commands.containsKey(commandName)) {
        _command = _shell.commands[commandName];
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

    var requiredOptions = command.requiredOptions;
    if (!requiredOptions.isEmpty) {
      var found = false;
      for (var optionName in requiredOptions) {
        if (!argResults.wasParsed(optionName)) {
          print("Missing required command option '$optionName'.");
          found = true;
        }
      }

      if (found) {
        print("");
        _usageForCommand(command, argResults);
        return;
      }
    }

    var commandRest = command.rest;
    var argRest = argResults.rest;
    if (commandRest != null) {
      if (argRest.length > 1 && !commandRest.allowMultiple) {
        print("Command '$commandName' does not allow multiple arguments.");
        print("");
        _usageForCommand(command, argResults);
        return;
      }

      // Remaining arguments (rest) required
      if (argRest.isEmpty && commandRest.required) {
        if (commandRest.allowMultiple) {
          print("Command '$commandName' requires an argument(s).");
        } else {
          print("Command '$commandName' requires an argument.");
        }

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

  void _executeCommand(ArgsCommand command, MethodMirror method, ArgResults argResults) {
    var program = reflectClass(TProgram).newInstance(new Symbol(""), []);
    var namedArguments = {};
    var positionalArguments = [];
    var parameters = method.parameters;
    if (command.rest != null) {
      if (command.rest.allowMultiple) {
        positionalArguments.add(argResults.rest);
      } else {
        if (argResults.rest.isEmpty) {
          positionalArguments.add(null);
        } else {
          positionalArguments.add(argResults.rest.first);
        }
      }
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
    for (var key in _shell.commands.keys) {
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
    if (_shell.name != null && !_shell.name.isEmpty) {
      return _shell.name;
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

  void _logError(String message) {
    _hasErrors = true;
    _logger.shout(message);
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

  void _parse(Map configuration) {
    var parser = new ArgsParser();
    _shell = parser.parse(configuration);
  }

  void _reset() {
    _arguments = <String>[];
    _command = null;
    _hasErrors = false;
    _logger = new Logger("ArgsHelper");
    _shell = null;
    _logger.onRecord.listen((LogRecord record) {
      print(record.message);
    });
  }

  void _usage() {
    var sb = new StringBuffer();
    if (_shell.description != null && !_shell.description.isEmpty) {
      sb.writeln(_shell.description);
    }

    sb.write("Usage: ");
    sb.write(_getScriptName());
    sb.writeln(" command [options] [arguments]");

    if (!_shell.commands.isEmpty) {
      sb.writeln("List of available commands:");
    }

    var commands = _shell.commands.values.toList();
    commands.sort((a, b) => a.name.compareTo(b.name));
    int maxLength = commands.fold(0, (l, e) => e.name.length > l ? e.name.length : l);

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
    if (_shell.description != null && !_shell.description.isEmpty) {
      sb.writeln(_shell.description);
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
      var command = _shell.commands[key];
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
