part of args_helper.args_parser;

class ArgsParser {
  Map<String, ArgsCommand> _commands;

  Map _configuration;

  String _description;

  String _name;

  ArgsShell parse(Map configuration) {
    if (configuration == null) {
      throw new ArgumentError("configuration: $configuration");
    }

    _configuration = configuration;
    _reset();
    _parseHeader();
    _parseCommands();
    var shell = new ArgsShell(commands: _commands, description: _description, name: _name);
    return shell;
  }

  bool _configGetBool(Map config, String name, bool defaultValue, List<String> parents) {
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

  List _configGetList(Map config, String name, List defaultValue, List<String> parents) {
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

  Map _configGetMap(Map config, String name, Map defaultValue, List<String> parents) {
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

  String _configGetString(Map config, String name, String defaultValue, List<String> parents) {
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
    var command = new ArgsCommand(argParser: original.argParser, description: original.description, name: commandName, original: original, requiredOptions: original.requiredOptions, rest: original.rest);
    return command;
  }

  void _errorSectionTypeMismatch(String name, Type type, List<String> parents) {
    var parts = parents.toList();
    parts.add(name);
    var section = _getSectionName(parts);
    throw new FormatException("Section '$section' must be of type '$type'.");
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
      var allowMultiple = _configGetBool(restSection, "allowMultiple", true, restParent);
      var help = _configGetString(restSection, "help", null, restParent);
      var name = _configGetString(restSection, "name", null, restParent);
      var required = _configGetBool(restSection, "required", false, restParent);
      var usage = _configGetString(restSection, "usage", null, restParent);
      rest = new ArgsRest(allowMultiple: allowMultiple, help: help, name: name, required: required, usage: usage);
    }

    var parser = new ArgParser();
    var command = new ArgsCommand(argParser: parser, description: description, name: commandName, requiredOptions: new Set<String>(), rest: rest);
    _commands[commandName] = command;
    if (options == null) {
      options = {};
    }

    _parseOptions(command, options, parser, ["commands", commandName, "options"]);
    if (!parser.options.containsKey("help")) {
      parser.addFlag("help", abbr: "h", help: "Print usage information for this command.", negatable: false);
    }

    return command;
  }

  void _parseCommands() {
    Map commands = _configGetMap(_configuration, "commands", null, []);
    if (commands == null) {
      throw new FormatException("Section 'commands' not found.");
    }

    for (var key in commands.keys) {
      key = "$key";
      var parent = ["commands"];
      var commandName = _normalizeCommandName(key);
      if (commandName.isEmpty) {
        throw new FormatException("Command must have a name.");
      }

      var commandSection = _configGetMap(commands, key, {}, parent);
      var command = _parseCommand(commandName, commandSection, parent);
      _commands[commandName] = command;
      var aliasesParent = <String>[];
      aliasesParent.addAll(parent);
      aliasesParent.add(key);
      var aliases = _configGetList(commandSection, "aliases", [], aliasesParent);
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

  void _parseOptions(ArgsCommand command, Map options, ArgParser parser, List parents) {
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
        parser.addFlag(optionName, abbr: abbr, defaultsTo: defaultsTo, help: help, hide: hide, negatable: negatable);
      } else {
        var allowed = <String>[];
        for (var element in _configGetList(option, "allowed", [], parent)) {
          allowed.add(element.toString());
        }

        if (allowed.isEmpty) {
          allowed = null;
        }

        var allowedHelp = <String, String>{};
        Map allowedHelpSection = _configGetMap(option, "allowedHelp", {}, parent);
        for (var key in allowedHelpSection.keys) {
          allowedHelp[key.toString()] = allowedHelpSection[key].toString();
        }

        if (allowedHelp.isEmpty) {
          allowedHelp = null;
        }

        var allowMultiple = _configGetBool(option, "allowMultiple", false, parent);
        var defaultsTo = _configGetString(option, "defaultsTo", null, parent);
        var valueHelp = _configGetString(option, "valueHelp", null, parent);
        parser.addOption(optionName, abbr: abbr, allowed: allowed, allowedHelp: allowedHelp, allowMultiple: allowMultiple, defaultsTo: defaultsTo, help: help, hide: hide, valueHelp: valueHelp);
        var required = _configGetBool(option, "required", false, parent);
        if (required) {
          command.requiredOptions.add(optionName);
        }
      }
    }
  }

  void _reset() {
    _commands = <String, ArgsCommand>{};
    _description = null;
    _name = null;
  }
}
